# 🚀 AI Code Analyzer

AI-powered code analysis and architecture review for **any projects** using AWS Bedrock.

## ✨ Features

- 🔍 **Diff Analysis** - AI review of git changes across all file types
- 🏗️ **Architecture Audit** - Architecture compliance & best practices
- 💬 **Ask Mode** - Code questions & development guidance
- 📊 **Markdown Reports** - Professional output formatting
- 🌐 **Multi-language** - Works with C#, Java, Python, JavaScript, Go, etc.

## 🚀 Quick Start

```powershell
# Clone and run
git clone https://github.com/yourusername/CodeAnalyzer
cd CodeAnalyzer

# Analyze any project
.\Analyzer.ps1 -Mode diff -ProjectPath "..\MyProject" -CompareBranch main

# Architecture audit
.\Analyzer.ps1 -Mode architecture -ProjectPath "..\MyProject"

# Ask code questions
.\Analyzer.ps1 -Mode ask -Query "How to improve this architecture?"

## ⚙️ Configuration

1. Copy `config.json.example` to `config.json`
2. Fill in your AWS Bedrock settings:
```json
{
    "modelId": "your-aws-bedrock-model-id",
    "awsRegion": "your-aws-region"
}
