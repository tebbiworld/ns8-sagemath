*** Settings ***
Library     SSHLibrary
Resource    api.resource

*** Variables ***
${CONFIG}    {"host":"sagemath.ci.test","lets_encrypt":false,"http2https":true,"admin_users":"ciadmin","ldap_enabled":true,"ldap_url":"ldaps://ldap.ci.test:636","ldap_base_dn":"dc=ci,dc=test","ldap_bind_dn":"cn=reader,dc=ci,dc=test","ldap_bind_password":"Bind#Pass 1","ldap_group":"","ldap_user_attribute":"uid"}

*** Test Cases ***
Install the module
    IF    '${SCENARIO}' == 'update'
        ${output}  ${rc} =    Execute Command    add-module ${UPDATE_FROM} 1    return_rc=True
    ELSE
        ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1    return_rc=True
    END
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Global Variable    ${module_id}    ${output.module_id}

Configure the module
    Run task    module/${module_id}/configure-module    ${CONFIG}    decode_json=${FALSE}

JupyterHub answers behind Traefik
    Wait Until Keyword Succeeds    90 times    10 seconds    Hub login page is served

Update to the image under test
    Skip If    '${SCENARIO}' != 'update'    scenario is ${SCENARIO}
    Run on node    api-cli run update-module --data '{"force":true,"module_url":"${IMAGE_URL}","instances":["${module_id}"]}'
    Wait Until Keyword Succeeds    90 times    10 seconds    Hub login page is served

Configuration reads back
    ${cfg} =    Run task    module/${module_id}/get-configuration    {}
    Should Be Equal    ${cfg['host']}    sagemath.ci.test
    Should Be Equal    ${cfg['admin_users']}    ciadmin
    Should Be Equal    ${cfg['ldap_bind_password']}    Bind#Pass 1

Secrets are stored in passwords.env only
    Secrets are kept out of the module environment    ${module_id}
    ${mode} =    Run on node    runagent -m ${module_id} bash -c 'stat -c \%a "$AGENT_STATE_DIR/hub.env"'
    Should Be Equal As Strings    ${mode.strip()}    600

*** Keywords ***
Hub login page is served
    ${out} =    Run on node    curl -fsSkL -H 'Host: sagemath.ci.test' https://127.0.0.1/hub/login
    Should Contain    ${out}    JupyterHub
