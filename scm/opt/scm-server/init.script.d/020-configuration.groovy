import sonia.scm.config.ScmConfiguration
import sonia.scm.util.ScmConfigurationUtil
import groovy.json.JsonSlurper

import org.slf4j.Logger
import org.slf4j.LoggerFactory

def logger = LoggerFactory.getLogger("sonia.scm.configuration.groovy")

def config = injector.getInstance(ScmConfiguration.class)
def env = System.getenv()

// set admin group
if (config.getAdminGroups() == null) {
    config.setAdminGroups(new HashSet())
} else {
    config.getAdminGroups().clear()
}

String adminGroup = env['ADMIN_GROUP']
if (adminGroup != null && adminGroup.length() > 0) {
    logger.info("Adding admin group ${adminGroup}")
    config.getAdminGroups().add(adminGroup)
} else {
    logger.warn("admin Group emtpy. None set.")
}

// set base url
String fqdn = env['FQDN']
logger.info("Setting FQDN ${fqdn}")
config.setBaseUrl("https://${fqdn}/scm")

// store configuration
ScmConfigurationUtil.getInstance().store(config)