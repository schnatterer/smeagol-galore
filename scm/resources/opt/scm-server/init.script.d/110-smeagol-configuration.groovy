// this script configures the smeagol plugin

import sonia.scm.*

def findClass(clazzAsString) {
    return Class.forName(clazzAsString, true, Thread.currentThread().getContextClassLoader())
}

def setSmeagolConfig(){
    String fqdn = System.getenv('FQDN')
    String smeagolUrl = "https://${fqdn}/smeagol"

    def smeagolConfiguration = injector.getInstance(findClass("com.cloudogu.smeagol.SmeagolConfiguration"))
    def currentConfig = smeagolConfiguration.get()
    currentConfig.setSmeagolUrl(smeagolUrl)
    currentConfig.setEnabled(true)
    currentConfig.setNavLinkEnabled(true)
    smeagolConfiguration.set(currentConfig)
}

try {
    setSmeagolConfig()
} catch( ClassNotFoundException e ) {
    println "Smeagol plugin seems not to be installed"
}