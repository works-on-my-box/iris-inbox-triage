package triage;

import com.intersystems.enslib.pex.BusinessOperation;
import com.intersystems.jdbc.IRISObject;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.time.Instant;

/**
 * Triage.Export: a Business Operation written in Java with PEX. Both triage processes send it every decision
 * (Triage.Msg.Decision) asynchronously, and it appends each one to a JSON Lines file, one object per line, for tools
 * outside IRIS: jq, a spreadsheet, a log shipper. The email body stays in IRIS.
 */
public class ExportOperation extends BusinessOperation {

    /** The file to append to: the item's %remoteSettings (Path=...), which Triage.Setup.Configure fills in. */
    public String Path = "decisions.jsonl";

    private Path file;

    @Override
    public void OnInit() throws Exception {
        file = Paths.get(Path).toAbsolutePath();
        Files.createDirectories(file.getParent());
        LOGINFO("Appending decisions to " + file);
    }

    @Override
    public void OnTearDown() throws Exception {
    }

    @Override
    public Object OnMessage(Object request) throws Exception {
        String line = toJson((IRISObject) request) + "\n";
        Files.write(file, line.getBytes(StandardCharsets.UTF_8), StandardOpenOption.CREATE, StandardOpenOption.APPEND);
        return null;
    }

    /** One decision as a JSON object; the properties are read from the IRIS message through its proxy. */
    public static String toJson(IRISObject decision) {
        StringBuilder json = new StringBuilder("{\"exportedAt\":\"").append(Instant.now()).append('"');
        json.append(",\"decisionId\":").append(decision.getLong("DecisionId"));
        String[][] fields = {{"messageId", "MessageId"}, {"sender", "Sender"}, {"subject", "Subject"},
            {"category", "Category"}, {"urgency", "Urgency"}, {"action", "Action"}, {"reason", "Reason"}};
        for (String[] field : fields) {
            json.append(",\"").append(field[0]).append("\":").append(quote(decision.getString(field[1])));
        }
        json.append(",\"confidence\":").append(decision.getBigDecimal("Confidence"));
        return json.append('}').toString();
    }

    static String quote(String text) {
        if (text == null) {
            return "null";
        }
        StringBuilder out = new StringBuilder(text.length() + 2).append('"');
        for (char c : text.toCharArray()) {
            switch (c) {
                case '"': out.append("\\\""); break;
                case '\\': out.append("\\\\"); break;
                case '\n': out.append("\\n"); break;
                case '\r': out.append("\\r"); break;
                case '\t': out.append("\\t"); break;
                default:
                    if (c < 0x20 || c == ' ' || c == ' ') {
                        out.append(String.format("\\u%04x", (int) c));
                    } else {
                        out.append(c);
                    }
            }
        }
        return out.append('"').toString();
    }
}
