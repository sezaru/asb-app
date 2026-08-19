// Throwaway decoder for a session replay log: prints seq/turn/payload as ground
// truth for the multi-client fidelity diff.
use asb_protocol::model::Payload;
use asb_protocol::replay::ReplayLog;
use std::path::Path;

fn main() {
    let arg = std::env::args().nth(1).expect("usage: dumplog <path/to/session.log>");
    let p = Path::new(&arg);
    let dir = p.parent().unwrap_or_else(|| Path::new("."));
    let session = p.file_stem().unwrap().to_str().unwrap();
    let log = ReplayLog::open(dir, session).expect("open");
    let ups = log.read_since(0).expect("scan");
    for u in &ups {
        let (kind, snip): (&str, String) = match &u.payload {
            Payload::AgentMessage { text } => ("agent_message", text.clone()),
            Payload::Thought { text } => ("thought", text.clone()),
            Payload::ToolCall(tc) => ("tool_call", format!("{tc:?}")),
            Payload::ToolCallUpdate { id, status, content } => (
                "tool_call_update",
                format!("id={id} status={status:?} content={content:?}"),
            ),
            Payload::Plan { entries } => ("plan", format!("{entries:?}")),
            Payload::Usage { input, output } => ("usage", format!("in={input} out={output}")),
            Payload::UserMessage { text } => ("user_message", text.clone()),
        };
        let snip: String = snip.chars().take(80).collect::<String>().replace('\n', " ");
        println!("seq={}\tturn={}\t{}\t{}", u.seq, u.turn, kind, snip);
    }
    eprintln!("TOTAL {} records", ups.len());
}
