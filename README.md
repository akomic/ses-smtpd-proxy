# SMTP to SES Mail Proxy

This is a tiny little proxy that speaks unauthenticated SMTP on the front side
and makes calls to the SES
[SendRawEmail](https://docs.aws.amazon.com/ses/latest/APIReference/API_SendRawEmail.html)
on the back side.

Everything this software does is possible with a more fully-featured mail
server like Postfix but requires setting up Postfix (which is complicated) and,
if following best practices, rotating credentials every 90 days (which is
annoying). Because this integrates with the AWS SDK v2 it can be configured
through the normal SDK configuration channels such as the instance metadata
service which provides dynamic credentials or environment variables, in which
case you should still manually rotate credentials but have one choke-point to
do that.

## Command Line Options

The proxy supports the following command line options:

- `--enable-vault` - Enable fetching AWS IAM credentials from a Vault server (default: false)
- `--vault-path=path` - Full path to Vault credential (ex: "aws/creds/my-mail-user")
- `--cross-account-role=arn` - ARN of cross-account role to assume for SES access
- `--configuration-set-name=name` - SES Configuration Set name to use with SendRawEmail
- `--enable-prometheus` - Enable Prometheus metrics server (default: false)
- `--prometheus-bind=addr` - Address/port for Prometheus server (default: ":2501")
- `--enable-health-check` - Enable health check server (default: false)
- `--health-check-bind=addr` - Address/port for health check server (default: ":3000")
- `--version` - Show program version

## Hashicorp Vault Integration
The server supports using Hashicorp Vault to retrieve an AWS IAM user
credential using the AWS back-end. It will also renew this credential as
long as possible. This functionality is not enabled by default but can
be enabled with command line flags and environment variables.

The [standard environment variables](https://developer.hashicorp.com/vault/docs/commands#environment-variables)
are supported. Minimally ``VAULT_ADDR`` must be specified as a URL to the
Vault server. Additionally, to support
[AppRole](https://developer.hashicorp.com/vault/docs/auth/approle) authentication
``VAULT_APPROLE_ROLE_ID`` and ``VAULT_APPROLE_SECRET_ID`` are supported. If
these variables are found in the environment AppRole authentication will be
automatically attempted and failure of that will cause the server to fail
starting.

Once the proper environment variables are setup, enable
Vault integration by passing ``--enable-vault`` and
``--vault-path=secret-path`` on the command line. For example, assuming that
you have the AWS back-end mounted at ``aws/`` in Vault and you want to use an
IAM user credential called ``email-server``, run the proxy like so:

```
VAULT_ADDR="https://your-vault-server:8200/" \
VAULT_APPROLE_ROLE_ID="..." \
VAULT_APPROLE_SECRET_ID="..." \
    ./ses-smtpd-proxy --enable-vault \
        --vault-path=aws/creds/email-server localhost:2500
```

## Prometheus Integration
The server can optionally serve Prometheus metrics for messages sent and errors.
Prometheus metrics are **disabled by default** and must be explicitly enabled
with the `--enable-prometheus` flag. When enabled, metrics will be served on 
`:2501` at the path `/metrics` by default. The bind address and port can be
customized by passing `--prometheus-bind=bind-string` in the format
expected by Go's http.Server.

To enable Prometheus metrics:

```
./ses-smtpd-proxy --enable-prometheus
```

Available metrics:
- `smtpd_email_send_success_total` - Total number of successfully sent emails
- `smtpd_email_send_fail_total` - Total number of failed emails (with error type labels)
- `smtpd_ses_error_total` - Total number of SES-specific errors
- `smtpd_credential_renewal_success_total` - Vault credential renewal successes (if using Vault)
- `smtpd_credential_renewal_error_total` - Vault credential renewal errors (if using Vault)

## Health Check Integration

A simple health check can be enabled by passing `--enable-health-check` 
on the command line. A JSON response will be served on `:3000` at the 
path `/health` by default. The bind address and port can be
customized by passing `--health-check-bind=bind-string` in the format
expected by Go's http.Server. A sample response:

```json
{ "name": "ses-smtp-proxy", "status": "ok", "version": "v1.3.0" }
```

## Cross-Account Role Assumption
The server supports assuming a cross-account IAM role for SES access. This is
useful when running in environments like AWS EKS where the pod's IRSA role is
in one account but SES is in another account.

To enable cross-account role assumption, use the `--cross-account-role` flag:

```
./ses-smtpd-proxy --cross-account-role=arn:aws:iam::123456789012:role/SESCrossAccountRole
```

The cross-account role must have SES permissions and trust the role used by
the proxy (e.g., IRSA role in EKS).

## SES Configuration Sets

The proxy supports using SES Configuration Sets for tracking and analytics.
Specify a configuration set with the `--configuration-set-name` flag:

```
./ses-smtpd-proxy --configuration-set-name=my-config-set
```

When a configuration set is specified, it will be included in all SES API calls
and logged in the message send logs for tracking purposes.

## Usage
By default the command takes no arguments and will listen on port 2500 on all
interfaces. The listen interfaces and port can be specified as the only
argument separated with a colon like so:

```
./ses-smtpd-proxy 127.0.0.1:2600
```

If not using the Vault integration noted above, it is expected that your
environment is configured in some way that is supported by the AWS SDK v2.

## SMTP Library

This proxy uses the [go-smtp](https://github.com/emersion/go-smtp) library
for robust SMTP command parsing and RFC compliance, including proper handling
of email addresses with `<>` brackets and other SMTP protocol features.

## Security Warning
This server speaks plain unauthenticated SMTP (no TLS) so it's not suitable for
use in an untrusted environment nor on the public internet. I don't have these
use-cases but I would accept pull requests implementing these features if you
do have the use-case and want to add them.

## Building
To build the binary run `make ses-smtpd-proxy`.

To build a Docker image, which is based on Alpine Latest, run `make docker` or
`make publish`. The later command will build and push the image. To override
the defaults specify `DOCKER_REGISTRY`, `DOCKER_IMAGE_NAME`, and `DOCKER_TAG`
in the make command like so:

```
make DOCKER_REGISTRY=reg.example.com DOCKER_IMAGE_NAME=ses-proxy DOCKER_TAG=foo docker
```

## Automated Builds

The project includes GitHub Actions workflow that automatically builds and pushes
Docker images to Docker Hub when tags are pushed. Images are built for the
`linux/amd64` platform.

## Dependencies

This project uses:
- AWS SDK for Go v2 for SES integration
- [go-smtp](https://github.com/emersion/go-smtp) for SMTP server implementation
- Hashicorp Vault API for credential management
- Prometheus client for metrics

## Contributing
If you would like to contribute please visit the project's GitHub page and open
a pull request with your changes. To have the best experience contributing,
please:

* Don't break backwards compatibility of public interfaces
* Update the readme, if necessary
* Follow the coding style of the current code-base
* Ensure that your code is formatted by gofmt
* Validate that your changes work with Go 1.23+

All code is reviewed before acceptance and changes may be requested to better
follow the conventions of the existing API.

## Contributors
This project is made possible by the contributions of the following
individuals; listed here in the order they first contributed to the
project.

* Mike Crute (@mcrute)
* Thomas Dupas (@thomasdupas)
* Quentin Loos (@Kent1)
* Moriyoshi Koizumi (@moriyoshi)
* Jesse Mandel (@supergibbs)
