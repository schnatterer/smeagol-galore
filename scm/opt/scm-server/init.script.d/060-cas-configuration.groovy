
try {
    def cas = injector.getInstance( Class.forName("com.cloudogu.scm.cas.CasContext", true, Thread.currentThread().getContextClassLoader()) );
    def config = cas.get();

    String fqdn = env['FQDN']
    config.setCasUrl("https://${fqdn}/cas");
    config.setEnabled(true);

    cas.set(config);
} catch (ClassNotFoundException ex) {
    println "cas plugin seems not to be installed"
}
