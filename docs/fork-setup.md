# Set up DiaTweaks (Taj's fork) on this Mac

You are setting up DiaTweaks from the fork at https://github.com/tajshaik24/DiaTweaks on a Mac. Do every step in order and check each one before moving on. If a step fails, stop and report the exact error. Don't improvise a workaround.

## 1. Check the prerequisites

- Dia must be at `/Applications/Dia.app`. Check with `test -d /Applications/Dia.app`. If it's missing, stop and ask the user to move Dia into Applications.
- Apple's developer tools must be installed. Check with `xcode-select -p`. If that fails, run `xcode-select --install`, then ask the user to finish the dialog that appears and tell you when it's done. You can't click through it yourself.

## 2. Get the fork

If `~/DiaTweaks` doesn't exist:

```sh
git clone https://github.com/tajshaik24/DiaTweaks.git ~/DiaTweaks
```

If it does exist, check that `git -C ~/DiaTweaks remote get-url origin` points at `tajshaik24/DiaTweaks`.
- If it does, run `git -C ~/DiaTweaks pull`.
- If it points at `JaceThings/DiaTweaks`, run these:

  ```sh
  git -C ~/DiaTweaks remote rename origin upstream
  git -C ~/DiaTweaks remote add origin https://github.com/tajshaik24/DiaTweaks.git
  git -C ~/DiaTweaks fetch origin
  git -C ~/DiaTweaks checkout -B main origin/main
  ```

## 3. Install

```sh
~/DiaTweaks/install.sh --yes
```

- Dia quits and reopens, or the patched Dia is staged and takes over the next time Dia quits.
- macOS may ask about "Dia Safe Storage". Tell the user to enter their password and click **Always Allow**.

Check that the installed updater points at the fork. Find the `diapatch` the installer added to the PATH with `command -v diapatch` and run:

```sh
strings "$(command -v diapatch)" | grep tajshaik24/DiaTweaks
```

## 4. Apply the settings

Quit Dia, write the settings, then reopen Dia:

```sh
osascript -e 'quit app "Dia"'
sleep 2
for key in compactCommandBar compactCommandBarWithChat compactSidebarHeader \
           hideChatButton hideChatsButton hideNewTabLogo hidePersonalizeButton \
           hideRecentTabsButton hideSidebarButton hideSkillsSuggestions hideUpgradeBanner \
           icloudPasswords onePassword passkeys tidyTabs; do
  defaults write com.diapatches "$key" -bool true
done
defaults write com.diapatches devTools -bool false
open -a Dia
```

Leave every other `com.diapatches` key alone. Check the result with `defaults read com.diapatches`.

## 5. Verify

- Ask the user to open a new tab in Dia. Only the search bar should show, with no Dia logo, no Skills buttons and no Personalize button.
- Check for crashes in the 3 minutes after launch:

  ```sh
  ls -t ~/Library/Logs/DiagnosticReports | grep -i dia | head
  ```

  Any report newer than the install means something went wrong. Report its name and the first 40 lines.
- Use `/usr/bin/log`, not `log`. Some shells replace `log` with a function.

## Later: updating

```sh
cd ~/DiaTweaks && git pull && ./install.sh --yes
```

The fork has no GitHub releases until the user publishes one, so Dia's update check finds nothing to install. That's expected.
