# 🔧 Management commands cheatsheet

This document contains management commands that system administrators are likely to run repeatedly over the lifetime of the server nodes.

## Schedule a command to run at a certain time

Classic Linux system administration guides point to the `at` command for this
task, but `systemd-run` is a better alternative that does not require additional
packages and daemon processes to work.

It is important to specify an absolute path to the command to run. Under the
hood, `systemd-run` creates transient timer and service units, where the service
unit has the `ExecStart` property set to the specified command.

```bash
$ sudo systemd-run --description='Scheduled kernel update reboot' --on-calendar='2023-06-01 03:50:00 UTC' /usr/sbin/reboot
```

## View a game server terminal without opening additional SSH connections

When run as root, `machinectl` can be used to create a complete terminal login
session for a given user, unlike with `su` or `sudo`, which do not trigger the
startup of `systemd` user daemons.

```bash
$ sudo machinectl shell <USER>@ [ABSOLUTE PATH TO COMMAND] [PARAMETERS...]
```

## View group disk quota status

Checking disk quotas before or after operations that are likely to significantly
impact disk space usage can be helpful.

```bash
$ sudo repquota -ga
```
