<h1 align="center">
<a href="https://legacyupdate.net/unstrike">
Unstrike
</a>
</h1>

Unstrike can automatically rescue a Windows 10 or 11 installation that has been affected by the 19 July 2024 [CrowdStrike Falcon content update error](https://www.crowdstrike.com/blog/statement-on-falcon-content-update-for-windows-hosts/). This tool will create a new ISO file that can be copied to a USB drive using software such as [Rufus](https://rufus.ie/). All you need is an ISO image of [Windows 10](https://www.microsoft.com/software-download/windows10ISO) or [Windows 11](https://www.microsoft.com/software-download/windows11).

It’s important to know what’s running with high privileges in your network, which is why Unstrike is designed to be auditable. It makes use of a PowerShell script and the [mkisofs](https://manpages.ubuntu.com/manpages/noble/en/man1/mkisofs.1.html) program. Please review the script before executing it, to ensure it meets your needs and has not been compromised. It is also signed by Hashbang Productions, the developers of [Legacy Update](https://legacyupdate.net/), and many other [open-source projects](https://hashbang.productions/).

**DISCLAIMER: This software is provided “as is” and without any express or implied warranties, including, without limitation, the implied warranties of merchantability and fitness for a particular purpose. Use of this software is at your own risk.**

---

<h2 align="center">
<a href="https://github.com/LegacyUpdate/Unstrike/releases/latest">
Download Unstrike
</a>
</h2>

Compatible with Windows 10, version 1511 and later, Windows 11, Server 2019 and later
Requires a 64-bit Windows installation to run the script, and a 64-bit Windows installation ISO image

## Notes on signing

The PowerShell script is signed. If you want to quickly determine whether the script is safe to run, you can review the Digital Signature tab in the file properties.

The copy of mkisofs.exe included in the repository comes from VMware Workstation, as this was an existing signed binary that was readily accessible, and I feel this should be trustable as being safe and unmodified. The binary is signed by VMware, Inc., and can be reviewed [on VirusTotal](https://www.virustotal.com/gui/file/d48e6c387f09130a91831a9adda289967f0fb3874097d32f74e4ab00297f3af5).

## License

Licensed under the Apache License, version 2.0. Refer to [LICENSE.md](https://github.com/kirb/Unstrike/blob/main/LICENSE.md).

The repository includes a compiled copy of mkisofs.exe from cdrtools, licensed under the [GNU General Public License, version 2.0](https://codeberg.org/schilytools/schilytools/src/branch/master/mkisofs/COPYING).
