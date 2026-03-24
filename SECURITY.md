# Security Policy

## Supported Versions

MicroForge is currently in active development. Only the latest version is supported with security updates.

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take the security of MicroForge seriously. If you believe you have found a security vulnerability, please report it to us as soon as possible.

### How to Report

Please **do not** report security vulnerabilities via public GitHub issues. Instead, please send an email to [security@hejitech.com](mailto:security@hejitech.com) with a description of the issue.

We will acknowledge your report within 48 hours and provide an estimate for the time required to address the vulnerability.

## Security Architecture

MicroForge is designed with several layers of security to protect users and their data:

### 1. Sandboxed Code Execution
Forged micro-apps (AI-generated HTML/JS) are executed within a sandboxed WebView (`webview_flutter`). This isolation prevents the generated code from accessing sensitive device resources or the main application state directly. Communication is limited to a secure, Flutter-controlled JavaScript bridge (`window.MicroForge`).

### 2. Immutable Data Isolation
Micro-apps operate on an "Immutable Versioning" model. Each deployment has a unique `appId`, and data is scoped strictly to that ID. This prevents one version of an app (or a potentially malicious script) from accessing or corrupting the data of other apps or versions.

### 3. AI Safety & Prompt Injection
While MicroForge uses high-performance AI models (Gemini), we recognize the risk of prompt injection. Our system prompts are engineered to minimize these risks, and all AI-generated output is treated as untrusted content, restricted by the WebView sandbox and runtime environment.

### 4. Firebase Security
All cloud-stored data (conversations, micro-app metadata) is protected by Cloud Firestore Security Rules and Firebase App Check, ensuring that only authenticated users can access their own data via the official app.

## Disclosure Policy

When a vulnerability is reported, we follow these steps:
1.  **Verification**: Confirm the vulnerability and its impact.
2.  **Resolution**: Develop a fix and test it thoroughly.
3.  **Deployment**: Release the fix in the next available version.
4.  **Disclosure**: Publicly announce the vulnerability and the fix (if appropriate).

## Best Practices for Users

- **Review Forged Code**: While the platform provides a sandbox, users are encouraged to review AI-generated code before relying on it for critical tasks.
- **Limit Data Exposure**: Avoid pasting sensitive personal information (passwords, private keys) into the chat interface.
- **Use Trusted Models**: Stick to the default AI models provided by MicroForge, as they are configured with our safety and security guidelines.
