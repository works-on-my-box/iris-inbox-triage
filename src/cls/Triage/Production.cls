/// Inbox triage: mailbox (or inbox folder) -> agent verdict -> alert, review by a person (Workflow), draft reply or archive.
/// The mailbox is read over IMAP (Triage.Inbox.IMAP, a custom adapter in Embedded Python); the POP3 service
/// Triage.Inbox.Mail is the alternative and stays disabled unless MAIL_PROTOCOL=pop3 (Triage.Setup.Configure).
Class Triage.Production Extends Ens.Production
{

XData ProductionDefinition
{
<Production Name="Triage.Production" TestingEnabled="true" LogGeneralTraceEvents="false">
  <Description>Inbox triage with an IRIS AI Hub agent</Description>
  <ActorPoolSize>2</ActorPoolSize>
  <Item Name="Triage.Inbox.IMAP" Category="" ClassName="Triage.Service.IMAPInbox" PoolSize="1" Enabled="true" Foreground="false" LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="IMAPServer">mail</Setting>
    <Setting Target="Adapter" Name="IMAPPort">3143</Setting>
    <Setting Target="Adapter" Name="Credentials">TriageMail</Setting>
    <Setting Target="Adapter" Name="CallInterval">5</Setting>
    <Setting Target="Host" Name="TargetConfigName">Triage.ProcessBPL</Setting>
  </Item>
  <Item Name="Triage.Inbox.Mail" Category="" ClassName="Triage.Service.MailInbox" PoolSize="1" Enabled="false" Foreground="false" LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="POP3Server">mail</Setting>
    <Setting Target="Adapter" Name="POP3Port">3110</Setting>
    <Setting Target="Adapter" Name="Credentials">TriageMail</Setting>
    <Setting Target="Adapter" Name="CallInterval">5</Setting>
    <Setting Target="Adapter" Name="DeleteMessage">1</Setting>
    <Setting Target="Host" Name="TargetConfigName">Triage.ProcessBPL</Setting>
  </Item>
  <Item Name="Triage.Inbox.Folder" Category="" ClassName="Triage.Service.FileInbox" PoolSize="1" Enabled="true" Foreground="false" LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="FilePath">/data/inbox/</Setting>
    <Setting Target="Adapter" Name="FileSpec">*.eml</Setting>
    <Setting Target="Adapter" Name="ArchivePath">/data/processed/</Setting>
    <Setting Target="Adapter" Name="CallInterval">2</Setting>
  </Item>
  <Item Name="Triage.ProcessBPL" Category="" ClassName="Triage.Process.TriageBPL" PoolSize="1" Enabled="true" Foreground="false" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="Triage.Process" Category="" ClassName="Triage.Process.Triage" PoolSize="1" Enabled="true" Foreground="false" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="Triage.Agent" Category="" ClassName="Triage.Operation.Agent" PoolSize="1" Enabled="true" Foreground="false" LogTraceEvents="false" Schedule="">
    <Setting Target="Host" Name="RetryInterval">20</Setting>
    <Setting Target="Host" Name="FailureTimeout">180</Setting>
  </Item>
  <Item Name="Triage.Draft" Category="" ClassName="Triage.Operation.Draft" PoolSize="1" Enabled="true" Foreground="false" LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="SMTPServer">mail</Setting>
    <Setting Target="Adapter" Name="SMTPPort">3025</Setting>
    <Setting Target="Adapter" Name="Credentials">TriageMail</Setting>
    <Setting Target="Adapter" Name="From">triage@triage.local</Setting>
    <Setting Target="Host" Name="Owner">owner@triage.local</Setting>
    <Setting Target="Host" Name="RetryInterval">20</Setting>
    <Setting Target="Host" Name="FailureTimeout">180</Setting>
  </Item>
  <Item Name="Triage.Alert" Category="" ClassName="Triage.Operation.Alert" PoolSize="1" Enabled="true" Foreground="false" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="Triage.Review" Category="" ClassName="Triage.Process.ReviewBPL" PoolSize="1" Enabled="true" Foreground="false" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="Triage Reviewers" Category="" ClassName="EnsLib.Workflow.Operation" PoolSize="1" Enabled="true" Foreground="false" LogTraceEvents="false" Schedule="">
    <Setting Target="Host" Name="AutoCreateRole">1</Setting>
  </Item>
  <Item Name="Triage.Archive" Category="" ClassName="Triage.Operation.Archive" PoolSize="1" Enabled="true" Foreground="false" LogTraceEvents="false" Schedule="">
  </Item>
</Production>
}

}
