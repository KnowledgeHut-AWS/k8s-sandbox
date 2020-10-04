# K3D platform

## Introduction
This repo provides a modularized k8s platform based on K3D. The makefile will deploy platform components including prometheus, elk (elf), vault, and tekton.

## Getting started
To get started, use the following incantation:

```bash
make up
```

This will bring up a k3d cluster with the namespaces that will be used for the platform services and will reset the logs. It does not actually include any services though -- you must run those separately.

## Target Structure
All services can be installed and uninstalled using names like 'install-' and 'delete-'. All targets write logs, but you can reset the logs with `make logs`. 

## Target List

