package info.schnatterer.tomcat;

import org.apache.catalina.connector.Connector;
import org.apache.catalina.startup.Tomcat;
import org.apache.catalina.startup.VersionLoggerListener;

import java.io.File;

public class Main {

    public static final String DOMAIN = System.getenv("DOMAIN");
    public static final String CERT_FOLDER = System.getenv("CERT_DIR");
    public static final String PK = CERT_FOLDER + '/' + DOMAIN + "/privkey.pem";
    public static final String CRT = CERT_FOLDER + '/' + DOMAIN + "/cert.pem";
    public static final String CA = CERT_FOLDER + '/' + DOMAIN + "/fullchain.pem";

    public static final String DEFAULT_HTTP_PORT = "8080";
    public static final String DEFAULT_HTTPS_PORT = "8443";


    public static void main(String[] args) throws Exception {

        Tomcat tomcat = new Tomcat();
        String httpPort = System.getProperty("http.port", DEFAULT_HTTP_PORT);
        String httpsPort = System.getProperty("https.port", DEFAULT_HTTPS_PORT);
        String catalinaHome = "/tomcat";
        tomcat.setBaseDir(new File(catalinaHome).getAbsolutePath());

        // Log version info at startup
        tomcat.getServer().addLifecycleListener(new VersionLoggerListener()); 
        
        tomcat.addWebapp("", new File(catalinaHome + "/webapps/ROOT").getAbsolutePath());
        tomcat.addWebapp("/cas", new File(catalinaHome + "/webapps/cas").getAbsolutePath());
        tomcat.addWebapp("/smeagol", new File(catalinaHome + "/webapps/smeagol").getAbsolutePath());
        tomcat.addWebapp("/scm", new File(catalinaHome + "/webapps/scm").getAbsolutePath());

        ReloadingTomcatConnectorFactory.addHttpsConnector(tomcat, Integer.parseInt(httpsPort), PK, CRT, CA);

        addHttpConnector(tomcat, Integer.parseInt(httpPort));

        tomcat.start();
        tomcat.getServer().await();
    }

    private static void addHttpConnector(Tomcat tomcat, int httpPort) {
        // Create Standard HTTP connector
        // This creates an APR HTTP connector because AprLifecycleListener has been configured (in addHttpsConnector)
        Connector connector = new Connector("HTTP/1.1");
        connector.setPort(httpPort);
        tomcat.getService().addConnector(connector);
    }
}
