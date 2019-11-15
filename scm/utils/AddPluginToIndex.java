import org.w3c.dom.*;

import javax.xml.parsers.*;
import javax.xml.transform.*;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import java.io.File;
import java.math.BigInteger;
import java.nio.file.*;
import java.security.MessageDigest;

public class AddPluginToIndex {

    private static Document read(String path) throws Exception {
        DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
        DocumentBuilder db = dbf.newDocumentBuilder();
        return db.parse(new File(path));
    }

    private static void write(Document doc, String path) throws Exception {
        TransformerFactory transformerFactory = TransformerFactory.newInstance();
        Transformer transformer = transformerFactory.newTransformer();

        DOMSource source = new DOMSource(doc);
        StreamResult result = new StreamResult(path);

        transformer.transform(source, result);
    }

    private static String checksum(String path) throws Exception {
        byte[] b = Files.readAllBytes(Paths.get(path));
        byte[] hash = MessageDigest.getInstance("SHA-256").digest(b);
        return new BigInteger(1, hash).toString(16);
    }

    private static String name(String path) {
        return new File(path).getName();
    }

    public static void main(String[] args) throws Exception {
        String pluginIndex = args[0];

        Document doc = read(pluginIndex);

        Element root = doc.getDocumentElement();

        for (int i = 1; i < args.length; ++i) {
            Element plugins = doc.createElement("plugins");
            root.appendChild(plugins);

            String smp = args[i];

            Element checksum = doc.createElement("checksum");
            checksum.appendChild(doc.createTextNode(checksum(smp)));
            plugins.appendChild(checksum);

            Element name = doc.createElement("name");
            name.appendChild(doc.createTextNode(name(smp)));
            plugins.appendChild(name);
        }

        write(doc, pluginIndex);
    }

}
