---
name: AKS-MCP Server Issue
about: Report issues or feature requests related to AKS Model Context Protocol (MCP) Server
title: '[AKS-MCP] '
labels: 'ai, mcp, needs-triage'
assignees: ''

---

## Issue Type
- [ ] Bug report
- [ ] Feature request
- [ ] Documentation issue
- [ ] Integration problem
- [ ] Performance issue

## AKS-MCP Server Information
- **Version**: [e.g., v0.1.0]
- **Installation method**: [VS Code Extension / Manual binary / Docker container]
- **Operating System**: [e.g., Windows 10, macOS 13, Ubuntu 22.04]
- **AI Assistant**: [GitHub Copilot / Claude / Cursor / Other]

## Cluster Information
- **AKS Version**: [e.g., 1.28.5]
- **Node Count**: [e.g., 3]
- **Node Size**: [e.g., Standard_DS2_v2]
- **Resource Group**: [if not sensitive]
- **Region**: [e.g., East US]

## Issue Description
**Describe the issue**
A clear and concise description of what the issue is.

**Expected behavior**
A clear and concise description of what you expected to happen.

**Actual behavior**
A clear and concise description of what actually happened.

## Steps to Reproduce
1. Go to '...'
2. Run command '...'
3. Ask AI assistant '...'
4. See error

## Error Messages/Logs
```
Paste any relevant error messages or logs here
```

## MCP Configuration
```json
{
  "mcpServers": {
    "aks-mcp": {
      // Paste your relevant MCP configuration here (remove sensitive data)
    }
  }
}
```

## AI Assistant Interaction
**Prompt used**: 
```
Paste the exact prompt you used with your AI assistant
```

**AI Response**:
```
Paste the AI response or error message
```

## Authentication & Permissions
- [ ] Logged in to Azure CLI (`az login`)
- [ ] Can access cluster with kubectl
- [ ] Have appropriate RBAC permissions
- [ ] MCP server permission level: [readonly / readwrite / admin]

## Additional Context
Add any other context about the problem here, such as:
- Network configuration
- Security policies
- Custom Azure configurations
- Screenshots (if applicable)

## Workaround (if any)
If you found a temporary workaround, please describe it here.

## Related Issues
Link any related issues or documentation here.

---
**Note**: For issues specific to the AKS-MCP Server implementation, please also consider reporting them directly at [Azure/aks-mcp](https://github.com/Azure/aks-mcp/issues).