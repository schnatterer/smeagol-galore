// this script installs required plugins for scm-manager

import sonia.scm.plugin.PluginManager    
import org.slf4j.Logger    
import org.slf4j.LoggerFactory    

def logger = LoggerFactory.getLogger("sonia.scm.install-plugins.groovy")    
def env = System.getenv()

def plugins = [
   "de.triology.scm.plugins:scm-cas-plugin"
]    

def pluginManager = injector.getInstance(PluginManager.class)    
def available = pluginManager.getAvailable()    
def installed = pluginManager.getInstalled()    

def isInstalled(installed, id){
   for (def ip : installed){
       if (ip.getId(false).equals(id)){
           return true    
       }
   }
   return false    
}

def getLatestIdWithVersion(available, id){
   for (def ip : available){
       if (ip.getId(false).equals(id)){
           return ip.getId(true)    
       }
   }
   return null    
}

def restart = false    
for (def id : plugins){
  if (!isInstalled(installed, id)){
      def iwv = getLatestIdWithVersion(available, id)    
      logger.info "install missing plugin " + iwv    
      pluginManager.install(iwv)    
      restart = true    
  }
}

if (restart){
     logger.info( "Triggering restart of scm-manager")    

    Thread.start {
        // Wait for startup to finish. Otherwise restart via touching web.xml won't work.
        sleep(5000)
        logger.info( "restarting scm-manager")    

        String restartCommand = "touch ${env['CATALINA_HOME']}/webapps/scm/WEB-INF/web.xml"
        logger.trace("Executing: ${restartCommand}")    
        restartCommand.execute()

        logger.info( "Restart triggered")    
    }
}
