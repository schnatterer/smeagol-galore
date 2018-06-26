import sonia.scm.user.*
import org.slf4j.Logger
import org.slf4j.LoggerFactory

def logger = LoggerFactory.getLogger("sonia.scm.deactivate-scmadmin.groovy")

def users = ['anonymous', 'scmadmin']

def userManager = injector.getInstance(UserManager.class)

for (def userName : users) {
    def user = userManager.get(userName)
    if (user.type == 'xml'){
        logger.info("Deactivating user ${user}")
        user.setActive(false)
        userManager.modify(user)
    }
}
