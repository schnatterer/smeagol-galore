import org.slf4j.LoggerFactory
import sonia.scm.config.ScmConfiguration
import sonia.scm.group.Group
import sonia.scm.group.GroupManager
import sonia.scm.security.PermissionAssigner
import sonia.scm.security.PermissionDescriptor
import sonia.scm.util.ScmConfigurationUtil

def logger = LoggerFactory.getLogger("sonia.scm.configuration.groovy")

def config = injector.getInstance(ScmConfiguration.class);
config.setNamespaceStrategy("CustomNamespaceStrategy");
// set base url
String fqdn = System.getenv('FQDN')
logger.info("Setting FQDN ${fqdn}")
config.setBaseUrl("https://${fqdn}/scm")

// disable anonymous access (this leads to an unreachable instance at the moment)
config.setAnonymousAccessEnabled(false);

// store configuration
ScmConfigurationUtil.getInstance().store(config);

// set admin group
String adminGroup = System.getenv('ADMIN_GROUP');
GroupManager groupManager = injector.getInstance(GroupManager.class);

Group group = groupManager.get(adminGroup);
if (group == null) {
    group = new Group("cas", adminGroup);
    group.setExternal(true);

    group = groupManager.create(group);
}

PermissionAssigner permissionAssigner = injector.getInstance(PermissionAssigner.class);
PermissionDescriptor descriptor = new PermissionDescriptor("*");
permissionAssigner.setPermissionsForGroup(adminGroup, Collections.singleton(descriptor));