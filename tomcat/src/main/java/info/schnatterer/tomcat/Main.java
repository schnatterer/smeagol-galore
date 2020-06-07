package info.schnatterer.tomcat;

import org.apache.catalina.startup.Tomcat;
import org.apache.catalina.startup.VersionLoggerListener;

import java.io.File;

public class Main {

    public static final String CERT_FOLDER = "/config/certs";
    public static final String PK = CERT_FOLDER +"/pk.pem";
    public static final String CRT = CERT_FOLDER + "/crt.pem";
    public static final String CA = CERT_FOLDER + "/ca.crt.pem";

    public static void main(String[] args) throws Exception {

        Tomcat tomcat = new Tomcat();
        tomcat.setPort(Integer.parseInt(System.getProperty("http.port")));
        String catalinaHome = "/tomcat";
        tomcat.setBaseDir(new File(catalinaHome).getAbsolutePath());

        // Log version info at startup
        tomcat.getServer().addLifecycleListener(new VersionLoggerListener()); 
        
        tomcat.addWebapp("", new File(catalinaHome + "/webapps/ROOT").getAbsolutePath());
        tomcat.addWebapp("/cas", new File(catalinaHome + "/webapps/cas").getAbsolutePath());
        tomcat.addWebapp("/smeagol", new File(catalinaHome + "/webapps/smeagol").getAbsolutePath());
        tomcat.addWebapp("/scm", new File(catalinaHome + "/webapps/scm").getAbsolutePath());

        ReloadingTomcatConnectorFactory.addHttpsConnector(tomcat, Integer.parseInt(System.getProperty("https.port")), PK, CRT, CA);

        // Without this call the connector seems not to start
        tomcat.getConnector();
        
        tomcat.start();
        tomcat.getServer().await();
    }
}
