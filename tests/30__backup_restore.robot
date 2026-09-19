*** Settings ***
Library     SSHLibrary
Resource    api.resource

*** Test Cases ***
Seed a probe file
    Run on node    runagent -m ${module_id} podman exec sagemath sh -c 'echo pre-backup > /srv/userhomes/ci_probe.txt'

Back up the module
    ${repo}    ${path} =    Back up the module to the cluster repository    ${module_id}
    Set Global Variable    ${BACKUP_REPO}    ${repo}
    Set Global Variable    ${BACKUP_PATH}    ${path}

Restore into a new instance
    ${rid} =    Restore the module from the cluster repository    ${BACKUP_REPO}    ${BACKUP_PATH}
    Set Global Variable    ${restored_id}    ${rid}
    Should Not Be Equal    ${restored_id}    ${module_id}

The restored instance has data, settings and secrets
    ${out} =    Wait Until Keyword Succeeds    60 times    10 seconds
    ...    Run on node    runagent -m ${restored_id} podman exec sagemath cat /srv/userhomes/ci_probe.txt
    Should Contain    ${out}    pre-backup
    ${cfg} =    Run task    module/${restored_id}/get-configuration    {}
    Should Be Equal    ${cfg['admin_users']}    ciadmin
    Should Be Equal    ${cfg['ldap_bind_password']}    Bind#Pass 1
    Secrets are kept out of the module environment    ${restored_id}
