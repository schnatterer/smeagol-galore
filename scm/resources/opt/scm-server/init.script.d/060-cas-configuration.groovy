import java.util.regex.Pattern

try {
    def cas = injector.getInstance( Class.forName("com.cloudogu.scm.cas.CasContext", true, Thread.currentThread().getContextClassLoader()) );
    def config = cas.get();

    String fqdn = System.getenv('FQDN')
    config.setCasUrl("https://${fqdn}/cas")
    config.setEnabled(true);
    String escapedFqdn = Pattern.quote(fqdn)
    config.setAllowedProxyChains("^https://${escapedFqdn}/.*\$")

    cas.set(config)
} catch (ClassNotFoundException ex) {
    println "cas plugin seems not to be installed"
}
