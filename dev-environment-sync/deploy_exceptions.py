"""Handling for repositories whose version cannot be resolved with the
standard "tag on the release branch tip" logic used by sync_dev_environment.

Some repositories build more than one deployable artefact from the same
commit - either via several sequential jobs in one workflow, or via entirely
separate, unordered workflows - so a single release branch tag cannot be
reliably attributed to a specific artefact. For these repositories the
deploy workflow's run-name (rendered per-run by GitHub, e.g. "Deploying
draft-metadata-checks v269 to intg") is used instead, as it records exactly
what was deployed, to where, and as what.

Repositories needing this handling are listed in MULTI_ARTEFACT_RUN_NAME_PARSERS.
"""

import re


def _parse_single_artefact_run_name(run_name):
    """"Deploying draft-metadata-checks v269 to intg" -> ({"draft-metadata-checks": "v269"}, "intg")"""
    match = re.match(r"^Deploying (?P<name>[\w.-]+) (?P<version>v[\w.]+) to (?P<environment>\w+)$", run_name)
    if not match:
        return None
    return {match["name"]: match["version"]}, match["environment"]


def _parse_create_db_users_run_name(run_name):
    """"Deploying Create Database Users Lambdas v406 and v407 to intg" ->
    ({"keycloak-users": "v406", "db-users": "v407"}, "intg")"""
    match = re.match(
        r"^Deploying Create Database Users Lambdas (?P<keycloak>v\d+) and (?P<db>v\d+) to (?P<environment>\w+)$",
        run_name
    )
    if not match:
        return None
    return {"keycloak-users": match["keycloak"], "db-users": match["db"]}, match["environment"]


# Maps a repository name to a function which parses its deploy workflow's
# run-name into ({artefact name: version}, environment). A repository
# appearing here is handled by sync_multi_artefact_service() below instead of
# sync_dev_environment.sync_service()'s standard tag-based logic.
MULTI_ARTEFACT_RUN_NAME_PARSERS = {
    "tdr-draft-metadata-validator": _parse_single_artefact_run_name,
    "tdr-create-db-users": _parse_create_db_users_run_name,
}


def deployed_version(session, url, repository, workflow, name, environment):
    """Return the version most recently deployed to an environment for a
    named artefact, based on the deploy workflow's run history.
    """
    parse_run_name = MULTI_ARTEFACT_RUN_NAME_PARSERS[repository]
    page = 1
    while page <= 3:  # a few hundred runs comfortably covers recent history
        response = session.get(
            url(repository, f"actions/workflows/{workflow}/runs?per_page=100&page={page}&status=success")
        )
        response.raise_for_status()
        runs = response.json().get("workflow_runs", [])
        if not runs:
            break
        for run in runs:
            parsed = parse_run_name(run.get("name") or "")
            if not parsed:
                continue
            versions, run_environment = parsed
            if run_environment == environment and name in versions:
                return versions[name]
        page += 1
    return None


def sync_multi_artefact_service(session, url, dispatch, deployments_for,
                                 service, repository, workflow, results,
                                 source_environment, target_environment, default_version_input):
    """Sync a repository listed in MULTI_ARTEFACT_RUN_NAME_PARSERS, resolving
    each artefact's version from deploy history rather than a release tag.
    """
    to_deploy = []
    for deployment in deployments_for(service):
        name = deployment["name"]
        version_input = deployment.get("version_input", default_version_input)
        source_version = deployed_version(session, url, repository, workflow, name, source_environment)
        if source_version is None:
            print(f"  {name}: no successful {source_environment} deploy found, skipping")
            results["skipped"].append(f"{name} (no {source_environment} version)")
            continue
        target_version = deployed_version(session, url, repository, workflow, name, target_environment)
        if source_version == target_version:
            print(f"  {name}: already at {source_version}")
            results["up_to_date"].append(name)
            continue
        to_deploy.append((deployment, name, version_input, source_version, target_version))

    if not to_deploy:
        return

    if service.get("single_dispatch"):
        # All artefacts are deployed by one workflow run which requires every
        # version input at once (e.g. tdr-create-db-users' deploy workflow
        # takes both keycloak-to-deploy and db-to-deploy together), so they
        # must be combined into a single dispatch.
        inputs = {"environment": target_environment}
        inputs.update(service.get("extra_inputs", {}))
        for deployment, name, version_input, source_version, target_version in to_deploy:
            inputs[version_input] = source_version
            inputs.update(deployment.get("extra_inputs", {}))
        if dispatch(repository, workflow, inputs):
            for _, name, _, source_version, target_version in to_deploy:
                results["deployed"].append(f"{name} {target_version or 'untagged'} -> {source_version}")
        else:
            for _, name, _, source_version, _ in to_deploy:
                results["failed"].append(f"{name} {source_version}")
        return

    for deployment, name, version_input, source_version, target_version in to_deploy:
        inputs = {"environment": target_environment, version_input: source_version}
        inputs.update(service.get("extra_inputs", {}))
        inputs.update(deployment.get("extra_inputs", {}))
        if dispatch(repository, workflow, inputs):
            results["deployed"].append(f"{name} {target_version or 'untagged'} -> {source_version}")
        else:
            results["failed"].append(f"{name} {source_version}")
