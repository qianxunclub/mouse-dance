<template><div><h1 id="快速上手" tabindex="-1"><a class="header-anchor" href="#快速上手"><span>快速上手</span></a></h1>
<p>本指南帮助你在几分钟内完成 MouseDance 的安装、授权与快捷键配置。</p>
<h2 id="系统要求" tabindex="-1"><a class="header-anchor" href="#系统要求"><span>系统要求</span></a></h2>
<ul>
<li>macOS 14 或更高版本</li>
<li>一台及以上外接显示器（单屏用户也可以使用&quot;快捷切换&quot;以外的功能，但多屏体验最佳）</li>
</ul>
<h2 id="_1-下载与安装" tabindex="-1"><a class="header-anchor" href="#_1-下载与安装"><span>1. 下载与安装</span></a></h2>
<ol>
<li>前往 <a href="https://gitee.com/qianxunclub/mouse-dance/releases" target="_blank" rel="noopener noreferrer">Gitee Releases</a> 下载最新的 <code v-pre>MouseDance-x.x.x.dmg</code>。</li>
<li>打开 dmg，将 <code v-pre>MouseDance.app</code> 拖入&quot;应用程序&quot;文件夹。</li>
</ol>
<div class="hint-container warning">
<p class="hint-container-title">未签名应用提示</p>
<p>本应用未使用 Apple 开发者证书签名，首次打开时 macOS 可能提示&quot;应用已损坏，无法打开&quot;或&quot;无法验证开发者&quot;。这是未签名应用的正常提示，在终端执行以下命令解除 Gatekeeper 隔离即可：</p>
<div class="language-bash line-numbers-mode" data-highlighter="prismjs" data-ext="sh"><pre v-pre><code><span class="line">xattr <span class="token parameter variable">-cr</span> /Applications/MouseDance.app</span>
<span class="line"></span></code></pre>
<div class="line-numbers" aria-hidden="true" style="counter-reset:line-number 0"><div class="line-number"></div></div></div></div>
<ol start="3">
<li>正常双击打开 MouseDance，图标将出现在屏幕右上角菜单栏。</li>
</ol>
<h2 id="_2-授予-输入监控-权限" tabindex="-1"><a class="header-anchor" href="#_2-授予-输入监控-权限"><span>2. 授予&quot;输入监控&quot;权限</span></a></h2>
<p>全局快捷键监听依赖该权限，未授权时快捷键不会生效：</p>
<ol>
<li>首次启动后点击主窗口中的 <strong>前往授权…</strong>。</li>
<li>在系统设置中勾选 MouseDance；若列表中已存在，请关闭后重新打开开关。</li>
</ol>
<p>授权完成后，主窗口&quot;输入监控权限&quot;会显示 <strong>已授权</strong>。</p>
<h2 id="_3-为屏幕录制快捷键" tabindex="-1"><a class="header-anchor" href="#_3-为屏幕录制快捷键"><span>3. 为屏幕录制快捷键</span></a></h2>
<p>在主窗口 <strong>屏幕配置</strong> 区域：</p>
<ol>
<li>点击某块屏幕右侧的快捷键输入框。</li>
<li>按下想要的组合键（例如 <code v-pre>⌘⌥1</code>，即 Command + Option + 1）即完成录入。</li>
<li>再次点击输入框可重新录制。</li>
</ol>
<p>窗口会实时显示&quot;当前识别 N 块屏幕&quot;，插拔显示器后列表自动更新。</p>
<h2 id="_4-配置-快捷切换-可选" tabindex="-1"><a class="header-anchor" href="#_4-配置-快捷切换-可选"><span>4. 配置&quot;快捷切换&quot;（可选）</span></a></h2>
<p>在 <strong>全局配置</strong> 中录制一个快捷键，用于在当前屏幕和上一个活跃屏幕之间快速往返。</p>
<div class="hint-container tip">
<p class="hint-container-title">提示</p>
<p>也可以直接快速 <strong>双击 Command / Control / Option</strong> 进行录入，轻量且不易与其他软件冲突。</p>
</div>
<h2 id="_5-标记屏幕-可选" tabindex="-1"><a class="header-anchor" href="#_5-标记屏幕-可选"><span>5. 标记屏幕（可选）</span></a></h2>
<p>点击窗口右上角 <strong>标记屏幕</strong>，所有显示器上会临时叠加屏幕编号与已配置的快捷键，便于核对多屏排布。</p>
<h2 id="_6-开启-开机自启动-可选" tabindex="-1"><a class="header-anchor" href="#_6-开启-开机自启动-可选"><span>6. 开启&quot;开机自启动&quot;（可选）</span></a></h2>
<p>在 <strong>全局配置</strong> 中开启后，登录系统即自动运行，仅显示菜单栏图标，程序坞不显示图标。</p>
<h2 id="卸载" tabindex="-1"><a class="header-anchor" href="#卸载"><span>卸载</span></a></h2>
<ol>
<li>菜单栏图标 → <strong>退出 MouseDance</strong>。</li>
<li>将 <code v-pre>/Applications/MouseDance.app</code> 移入废纸篓。</li>
</ol>
<p>无其他残留文件。</p>
</div></template>


