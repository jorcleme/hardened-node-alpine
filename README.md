# Description

A hardened node.js alpine image with a minimal set of packages to run node.js applications. This image is based on the Hardened Alpine Linux image provided by the [Cisco Cloud9 Team](https://wwwin-github.cisco.com/pages/sto-ccc/cloud9-docs/).

## Cisco CA Bundle

Node.js uses a statically compiled, manually updated, hard-coded list of certificate authorities [Node.js Issue](https://github.com/nodejs/node/issues/4175). Node.js is compiled with root certificate authorities list replaced by [Cisco Core CA Bundle](https://www.cisco.com/security/pki/trs/ios_core.p7b). This bundle is a collection of root certificates that are trusted by Cisco intended to facilitate services connecting specifically to Cisco-owned resources. This bundle includes only the certificates considered necessary to connect to Cisco resources, including the main Cisco-operated roots as well as specific third-party roots such as QuoVadis/HydrantID that are commonly used to issue Cisco production SSL certificates.

Refer to [Cisco CS Trusted Root Store Program](https://cswiki.cisco.com/display/EXT/Cryptographic+Services%3A+Trusted+Root+Store+Program) for more information.

## Source

[GitHub](https://github.com/jorcleme/hardened-node-alpine)

## Hardened Image

[Cloud9 Hardened Alpine Linux](https://containers.cisco.com/repository/sto-ccc-cloud9/hardened_alpine)

## Other Details

Accessing external APIs requires that you extend the list with additional root certificates like [Cisco Trusted External Root Bundle](https://www.cisco.com/security/pki/trs/ios.p7b)

There are other trusted Root Stores like:
[Cisco Trusted Union Root Bundle](https://www.cisco.com/security/pki/trs/ios_union.p7b)
[Cisco Trusted FedRAMP Root Bundle](https://www.cisco.com/security/pki/trs/fedramp.p7b)

## Usage

Just pull this image and use it as a base image for your node.js application.

**Note:** The repository structure and tags are likely to change in the future. We will update this README accordingly.

```Dockerfile
FROM containers.cisco.com/jorcleme/smb-devs:latest
```

If you prefer Docker Compose, you can use the following snippet:

```yaml
version: '2'
services:
    node:
        image: containers.cisco.com/jorcleme/smb-devs:latest
        container_name: hardened-node-alpine
        user: 'node'
```
