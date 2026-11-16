import keypirinha as kp
import keypirinha_util as kpu


class SystemActions(kp.Plugin):
    """Native Keypirinha overlay for common Windows power actions."""

    def on_catalog(self):
        self.actions = {
            "Lock computer": ("rundll32.exe", "user32.dll,LockWorkStation"),
            "Sleep": ("rundll32.exe", "powrprof.dll,SetSuspendState 0,1,0"),
            "Hibernate": ("shutdown.exe", "/h"),
            "Sign out": ("shutdown.exe", "/l"),
            "Restart Windows": ("shutdown.exe", "/r /t 0"),
            "Shut down Windows": ("shutdown.exe", "/s /t 0"),
        }
        self.set_catalog([
            self.create_item(
                category=kp.ItemCategory.REFERENCE,
                label="power: " + label,
                short_desc="Windows system action",
                target=label,
                args_hint=kp.ItemArgsHint.FORBIDDEN,
                hit_hint=kp.ItemHitHint.NOARGS,
            )
            for label in self.actions
        ])

    def on_execute(self, item, action):
        command, args = self.actions[item.target()]
        kpu.shell_execute(command, args=args)

