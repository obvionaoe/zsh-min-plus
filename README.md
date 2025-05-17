# min+

A minimal, fast, and info-rich Zsh prompt designed to keep your terminal clean while giving you exactly what you need — no fluff, just the essentials.

## Features

- Minimal & Clear: Shortened path display (3 letters per directory) to save space without losing context
- Async Git Info: Displays current branch and status asynchronously for smooth performance
- Cloud Profiles: Shows AWS and GCP profiles with cool Nerd Fonts icons ( for AWS,  for GCP)
- Kubernetes Context: Displays current k8s context and namespace (⎈ icon)
- Exit Code Indicator: Quickly shows the last command's exit status (red ✘ on failure)
- Fast & Lightweight: Optimized for speed with asynchronous updates

## Requirements

- Zsh
- zsh-async for asynchronous Git prompt updates
- Nerd Fonts patched font for icons
- kubectl installed for Kubernetes info
- AWS CLI and GCP CLI configured for cloud profile detection
