"""Bring the TDR dev environment in line with the intg environment.

For each repository listed in services.json this script:
  * finds the version tag on the tip of the ``release-intg`` branch
  * compares it with the tag on the tip of the ``release-dev`` branch
  * dispatches the repository's deploy workflow for the dev environment when
    the two differ

The list of repositories is taken from the lambdas and ECS services described
in the "Creating a TDR environment from scratch" service recovery document.

Environment variables:
  GITHUB_API_TOKEN  token with permission to read branches/tags and to
                    dispatch workflows in the target repositories (required)
  SLACK_URL         Slack incoming webhook to post a summary to (optional)
  DRY_RUN           set to "true" to log what would be deployed without
                    dispatching any workflows (optional)
"""

import json
import os
import sys
import time
from datetime import datetime, timedelta, timezone

import requests

from multi_artefact import MULTI_ARTEFACT_REPOSITORIES, sync_multi_artefact_service

ORG = "nationalarchives"
SOURCE_ENVIRONMENT = "intg"
TARGET_ENVIRONMENT = "dev"
DEFAULT_WORKFLOW = "deploy.yml"
DEFAULT_VERSION_INPUT = "to-deploy"
# Pause between dispatches so we do not trip the GitHub API secondary rate limits
DISPATCH_DELAY_SECONDS = 2
E2E_POLL_SECONDS = 30
E2E_TIMEOUT_SECONDS = 3600
# Guards against deploying an ancient version from a release branch which is no
# longer being updated by its repository's deploy workflow.
MAX_SOURCE_AGE_DAYS = 120

session = requests.Session()
session.headers.update({
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "Authorization": f"Bearer {os.environ['GITHUB_API_TOKEN']}"
})

dry_run = os.environ.get("DRY_RUN", "false").lower() == "true"


def url(repository, suffix):
    base_url = f"https://api.github.com/repos/{ORG}/{repository}"

    if suffix:
        return f"{base_url}/{suffix}"

    return base_url


def branch_head(repository, environment):
    """Return the (sha, commit date) at the tip of a release branch."""
    response = session.get(url(repository, f"branches/release-{environment}"))
    if response.status_code == 404:
        return None, None
    response.raise_for_status()
    commit = response.json()["commit"]
    date = datetime.strptime(commit["commit"]["author"]["date"], "%Y-%m-%dT%H:%M:%SZ")
    return commit["sha"], date.replace(tzinfo=timezone.utc)


def tag_for_sha(repository, sha):
    """Return the release tag pointing at the given commit, if there is one."""
    if sha is None:
        return None
    page = 1
    while True:
        response = session.get(url(repository, f"tags?per_page=100&page={page}"))
        response.raise_for_status()
        tags = response.json()
        if not tags:
            return None
        for tag in tags:
            if tag["commit"]["sha"] == sha:
                return tag["name"]
        page += 1


def dispatch(repository, workflow, inputs):
    if dry_run:
        print(f"  [dry run] would dispatch {repository}/{workflow} with {inputs}")
        return True
    response = session.post(
        url(repository, f"actions/workflows/{workflow}/dispatches"),
        json={"ref": default_branch(repository), "inputs": inputs}
    )
    if response.status_code != 204:
        print(f"  failed to dispatch {repository}/{workflow}: "
              f"{response.status_code} {response.text}")
        return False
    print(f"  dispatched {repository}/{workflow} with {inputs}")
    time.sleep(DISPATCH_DELAY_SECONDS)
    return True


def default_branch(repository):
    response = session.get(url(repository, ""))
    response.raise_for_status()
    return response.json()["default_branch"]


def run_e2e_tests():
    """Dispatch one dev E2E run and return its final status."""
    if dry_run:
        print("  [dry run] would dispatch dev E2E tests")
        return "not run (dry run)"

    marker = f"dev-sync-{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}"
    response = session.post(
        url("tdr-e2e-tests", "actions/workflows/ci.yml/dispatches"),
        json={
            "ref": "master",
            "inputs": {
                "environment": TARGET_ENVIRONMENT,
                "repo-details": marker,
                "wait": "0",
            },
        },
    )
    if response.status_code != 204:
        print(f"  failed to dispatch dev E2E tests: {response.status_code} {response.text}")
        return "dispatch failed"

    deadline = time.monotonic() + E2E_TIMEOUT_SECONDS
    run = None
    while time.monotonic() < deadline:
        response = session.get(
            url("tdr-e2e-tests", "actions/workflows/ci.yml/runs?event=workflow_dispatch&per_page=20")
        )
        response.raise_for_status()
        runs = response.json().get("workflow_runs", [])
        run = next((candidate for candidate in runs if marker in candidate.get("display_title", "")), None)
        if run:
            break
        time.sleep(E2E_POLL_SECONDS)

    if run is None:
        print("  dev E2E tests dispatched, but the workflow run was not found before timeout")
        return "run not found"

    print(f"  dev E2E run: {run['html_url']}")
    while time.monotonic() < deadline:
        response = session.get(url("tdr-e2e-tests", f"actions/runs/{run['id']}"))
        response.raise_for_status()
        run = response.json()
        if run["status"] == "completed":
            return run.get("conclusion") or "completed without conclusion"
        time.sleep(E2E_POLL_SECONDS)

    return "timed out"


def deployments_for(service):
    """A repository deploys one artefact unless it declares several."""
    return service.get("deployments", [{"name": service["repository"]}])


def sync_service(service, results):
    repository = service["repository"]
    workflow = service.get("workflow", DEFAULT_WORKFLOW)
    version_inputs = service.get("version_inputs", [service.get("version_input", DEFAULT_VERSION_INPUT)])
    print(f"{repository}:")

    if service.get("enabled", True) is False:
        print(f"  disabled: {service.get('todo', 'no reason given')}")
        results["skipped"].append(f"{repository} (disabled)")
        return

    status_env = service.get("terraform_status_env")
    if status_env:
        terraform_status = os.environ.get(status_env, "unknown")
        if terraform_status != "clean":
            print(f"  skipping: {status_env} is '{terraform_status}', a manual terraform "
                  f"apply is required before this can be deployed unattended")
            results["skipped"].append(f"{repository} (pending terraform changes, status: {terraform_status})")
            return

    intg_sha, intg_date = branch_head(repository, SOURCE_ENVIRONMENT)
    if intg_sha is None:
        print(f"  no release-{SOURCE_ENVIRONMENT} branch found, skipping")
        results["skipped"].append(f"{repository} (no {SOURCE_ENVIRONMENT} branch)")
        return

    age = datetime.now(timezone.utc) - intg_date
    if age > timedelta(days=MAX_SOURCE_AGE_DAYS):
        print(f"  release-{SOURCE_ENVIRONMENT} is {age.days} days old, skipping as it "
              f"is unlikely to be maintained by the deploy workflow")
        results["skipped"].append(f"{repository} (stale {SOURCE_ENVIRONMENT} branch, {age.days} days old)")
        return

    if repository in MULTI_ARTEFACT_REPOSITORIES:
        # More than one artefact is built from the same commit, tagged
        # independently and in no guaranteed order, so a single release
        # branch tag cannot be attributed to a specific artefact - see
        # multi_artefact.py for how this is resolved instead.
        sync_multi_artefact_service(
            session, url, dispatch, deployments_for,
            service, repository, workflow, results,
            SOURCE_ENVIRONMENT, TARGET_ENVIRONMENT, DEFAULT_VERSION_INPUT
        )
        return

    intg_version = tag_for_sha(repository, intg_sha)
    if intg_version is None:
        print(f"  no release-{SOURCE_ENVIRONMENT} version found, skipping")
        results["skipped"].append(f"{repository} (no {SOURCE_ENVIRONMENT} version)")
        return

    dev_sha, _ = branch_head(repository, TARGET_ENVIRONMENT)
    dev_version = tag_for_sha(repository, dev_sha)
    # Some deploy workflows point the release branch at the default branch tip
    # rather than the deployed tag, so fall back to comparing commits.
    if intg_version == dev_version or (dev_version is None and dev_sha == intg_sha):
        print(f"  already at {intg_version}")
        results["up_to_date"].append(repository)
        return

    for deployment in deployments_for(service):
        name = deployment.get("name", repository)
        inputs = {"environment": TARGET_ENVIRONMENT}
        deployed_value = intg_version[1:] if service.get("strip_v_prefix") and intg_version.startswith("v") else intg_version
        inputs.update({version_input: deployed_value for version_input in version_inputs})
        inputs.update(service.get("extra_inputs", {}))
        inputs.update(deployment.get("extra_inputs", {}))
        if dispatch(repository, workflow, inputs):
            results["deployed"].append(f"{name} {dev_version or 'untagged'} -> {intg_version}")
        else:
            results["failed"].append(f"{name} {intg_version}")


def slack_message(results, terraform_warnings, e2e_status):
    lines = [f"*Dev environment sync* (bringing dev in line with {SOURCE_ENVIRONMENT})"]
    if results["deployed"]:
        lines.append("*Deployed:*\n" + "\n".join(f"• {item}" for item in results["deployed"]))
    else:
        lines.append("Nothing to deploy; dev is in line with intg.")
    if results["failed"]:
        lines.append("*Failed to dispatch:*\n" + "\n".join(f"• {item}" for item in results["failed"]))
    if results["skipped"]:
        lines.append("*Skipped:*\n" + "\n".join(f"• {item}" for item in results["skipped"]))
    if terraform_warnings:
        lines.append(":warning: *Terraform:*\n" + "\n".join(f"• {item}" for item in terraform_warnings))
    if e2e_status in ("success", "not run (dry run)"):
        lines.append(f"*Dev E2E tests:* {e2e_status}")
    else:
        lines.append(f":warning: *Dev E2E tests:* {e2e_status}")
    return {"blocks": [{"type": "section", "text": {"type": "mrkdwn", "text": "\n\n".join(lines)}}]}


# Repositories whose infrastructure is checked for drift alongside the
# lambda/ECS sync above. Maps a human-readable label to the environment
# variable (set by the calling workflow from a prior terraform plan job)
# holding that repository's plan status against dev: "clean", "drift" or
# "error".
TERRAFORM_STATUS_CHECKS = {
    "tdr-terraform-environments": "DEV_ENVIRONMENT_TERRAFORM_STATUS",
    "da-reference-generator": "REFERENCE_GENERATOR_TERRAFORM_STATUS",
}


def compute_terraform_warnings():
    warnings = []
    for label, env_var in TERRAFORM_STATUS_CHECKS.items():
        status = os.environ.get(env_var, "unknown")
        if status == "drift":
            warnings.append(f"{label} has pending changes against dev — manual `terraform apply` required")
        elif status != "clean":
            warnings.append(f"{label} terraform plan status could not be determined ({status}) — check the workflow run")
    return warnings


def main():
    try:
        with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "services.json")) as services_file:
            services = json.load(services_file)
    except json.JSONDecodeError as e:
        print(f"Error parsing services.json: {e}")
        return
    except FileNotFoundError:
        print("services.json file not found")
        return

    results = {"deployed": [], "up_to_date": [], "failed": [], "skipped": []}

    # ECS services are deployed first as the lambdas are not in the request path
    # for the long running services.
    for service in services["ecs"] + services["lambdas"]:
        sync_service(service, results)

    e2e_status = run_e2e_tests()
    message = slack_message(results, compute_terraform_warnings(), e2e_status)
    if "SLACK_URL" in os.environ and not dry_run:
        requests.post(os.environ["SLACK_URL"], json=message)
    else:
        print(json.dumps(message, indent=2))

    # A failing dev E2E run is reported above (Slack/stdout) but doesn't fail this
    # workflow - it doesn't indicate a problem with the sync itself, and dev's E2E
    # suite failing shouldn't be treated the same as a broken deploy dispatch.
    if results["failed"]:
        sys.exit(1)


if __name__ == "__main__":
    main()
