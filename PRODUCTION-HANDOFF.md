# HAProxy Production Handoff

## Problem

Current environment uses a Windows VM with `netsh interface portproxy` to forward TCP traffic on ports 1520 and 1521 to third-party Syntax endpoints hosted in AWS.

Connectivity to Syntax uses the existing private/Meraki network path.

The Syntax endpoints are DNS-backed and their IP addresses can change. The current netsh forwarding can become stale when the destination IP changes. A scheduled task/script currently refreshes the netsh rules as a workaround.

## POC Result

A working Azure HAProxy POC was completed.

The POC demonstrated:

- HAProxy running on Ubuntu 22.04
- TCP forwarding through port 1520
- Backend configured using an FQDN rather than a hard-coded IP
- Runtime DNS resolution configured in HAProxy
- Backend initially resolved to 10.50.1.20
- DNS was changed to 10.50.1.21
- HAProxy automatically moved new connections to 10.50.1.21
- DNS was changed back to 10.50.1.20 and HAProxy followed it
- No HAProxy restart, reload, configuration rewrite, or scheduled task was required

POC HAProxy backend:

backend demo-backend
    server demo syntax.demo.internal:8080 check inter 2s fall 2 rise 2 resolvers azure init-addr last,libc,none

## Proposed Production Direction

Potential architecture:

Application
    |
Azure Internal Load Balancer
    |
    +-- HAProxy VM 01
    |
    +-- HAProxy VM 02
            |
            v
Existing private/Meraki network path
            |
            v
        Syntax AWS

Both HAProxy VMs should dynamically resolve the actual Syntax FQDNs through the organization's existing DNS infrastructure.

Do NOT assume production should use Azure 168.63.129.16 simply because the POC did. Production likely uses Azure DNS Private Resolver or another internal DNS path.

## Information Needed Before Deployment

Inspect the existing environment and determine:

1. Actual Syntax FQDN(s).
2. Existing 1520 and 1521 source-to-destination port mappings.
3. DNS servers/resolver path used by the existing Windows VM.
4. DNS TTL and behavior of the Syntax records.
5. VNet/subnet where the replacement should run.
6. Effective routes/UDRs required for the existing Meraki/Syntax path.
7. NSG/firewall requirements.
8. How clients currently address the Windows forwarder.
9. Whether a stable frontend IP/DNS name must be preserved.
10. Expected TCP connection duration and appropriate HAProxy timeouts.
11. Availability-zone/availability requirements.
12. Logging/monitoring requirements.

Useful commands on the existing Windows forwarder:

netsh interface portproxy show all

Get-DnsClientServerAddress -AddressFamily IPv4

Resolve-DnsName <syntax-fqdn>

nslookup <syntax-fqdn>

Also inspect the scheduled task/script currently used to refresh the netsh rules.

## Production Requirements / Constraints

- Do not hard-code Syntax destination IPs.
- HAProxy backends should use Syntax FQDNs with runtime DNS resolution.
- Reuse existing DNS/network/routing/security patterns.
- Do not redesign unrelated networking.
- Production HAProxy should be private; remove the POC public-IP design.
- Evaluate two HAProxy VMs behind an Azure Standard Internal Load Balancer.
- Evaluate LB rules for TCP 1520 and 1521.
- Azure LB health probes should determine HAProxy node availability.
- HAProxy backend health checks should determine Syntax availability.
- Configure explicit backend recovery behavior.
- Keep the existing Windows/netsh forwarder available during initial validation/cutover for rollback.

## Today's Goal

Determine whether the two-VM HAProxy architecture can be deployed today.

Clearly separate:

- Verified facts
- Assumptions requiring validation
- Deployment blockers
- Non-blocking improvements

Start by understanding the existing production environment. Do not immediately generate or apply infrastructure until the actual network, DNS, Syntax endpoint, and port requirements have been established.

Keep the implementation minimal and supportable.



## Instructions for Company GPT

Use this document and the repository as the starting context for this work.

The HAProxy DNS re-resolution POC has already been successfully tested. Do not recreate the POC unless additional validation is required.

The immediate objective is to determine whether this can be adapted and deployed into the actual company environment today.

Before modifying infrastructure, help inspect and document the existing environment, including:

- Windows/netsh forwarding configuration
- Syntax FQDNs and destination ports
- DNS resolver architecture
- VNet/subnet placement
- UDRs and effective routes
- NSGs and firewall requirements
- Meraki/private connectivity to Syntax AWS
- Existing client ingress path
- Availability requirements

Maintain four categories as we work:

1. Verified facts
2. Assumptions
3. Items requiring validation
4. Deployment blockers

The likely target architecture is:

Application
    |
Azure Internal Load Balancer
    |
    +-- HAProxy VM 01
    |
    +-- HAProxy VM 02
            |
      Existing private/Meraki path
            |
        Syntax AWS

This architecture is a candidate, not yet a final decision.

Do not redesign unrelated company networking.

Once the actual environment has been validated and the production architecture agreed upon, produce clear implementation requirements that can be handed to Codex to modify the Terraform in this repository.