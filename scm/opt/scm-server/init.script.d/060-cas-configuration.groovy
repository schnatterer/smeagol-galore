import groovy.json.JsonSlurper

def env = System.getenv()

try {
    def cas = injector.getInstance(Class.forName("de.triology.scm.plugins.cas.CasAuthenticationHandler"))
        def config = cas.getConfig()

        String fqdn = env['FQDN']
        config.setCasServerUrl("https://${fqdn}/cas")

        config.setCasAttrUsername("username")
        config.setCasAttrDisplayName("displayName")
        config.setCasAttrMail("mail")
        config.setCasAttrGroup("groups")

        config.setTolerance("5000")
        config.setEnabled(true)

    cas.storeConfig(config)
} catch( Exception e ) {
    println "cas plugin seems not to be installed"
}