import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/liquid_scaffold.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _repoUrl = 'https://github.com/glxgo/heybuddy-schedule';
  static const _version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    return LiquidScaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          GlassCard(
            borderRadius: 30,
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            elevation: 1.4,
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColorTokens.primary,
                        AppColorTokens.primaryGradientEnd,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withAlpha(150),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColorTokens.primary.withAlpha(55),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '相伴课表',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'v$_version',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColorTokens.textTertiary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '大学生社交化课表管理应用',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColorTokens.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Section(
            title: '项目与许可',
            children: [
              _Tile(
                icon: Icons.code_rounded,
                title: '项目开源',
                subtitle: _repoUrl,
                onTap: () => launchUrl(Uri.parse(_repoUrl)),
              ),
              _Tile(
                icon: Icons.description_outlined,
                title: '开源许可',
                subtitle: '查看 Flutter 与 pub 依赖的完整许可证',
                onTap: () => showLicensePage(context: context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: '拾光课程表致谢',
            children: const [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Text(
                  '教务系统适配桥接规范参考了拾光课程表开源社区的公开方案。相关适配能力遵循 MIT 许可证的保留署名与来源致谢要求，本项目已在此保留致谢说明。',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColorTokens.textSecondary,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: '主要开源组件',
            children: const [
              _LicenseRow(name: 'Flutter', license: 'BSD-3-Clause'),
              _LicenseRow(name: 'Riverpod', license: 'MIT'),
              _LicenseRow(name: 'GoRouter', license: 'BSD-3-Clause'),
              _LicenseRow(name: 'sqflite', license: 'BSD-2-Clause'),
              _LicenseRow(name: 'Dio', license: 'MIT'),
              _LicenseRow(name: 'webview_flutter', license: 'BSD-3-Clause'),
              _LicenseRow(name: 'image_picker', license: 'BSD-3-Clause'),
              _LicenseRow(name: '拾光课程表适配规范', license: 'MIT'),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'Made with love by HeyBuddy Team',
              style: TextStyle(
                fontSize: 12,
                color: AppColorTokens.textTertiary.withAlpha(220),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColorTokens.textTertiary,
            ),
          ),
        ),
        GlassCard(
          borderRadius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 58,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColorTokens.primary.withAlpha(18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: AppColorTokens.primary),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: AppColorTokens.textTertiary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: AppColorTokens.textTertiary,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

class _LicenseRow extends StatelessWidget {
  final String name;
  final String license;

  const _LicenseRow({required this.name, required this.license});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      minTileHeight: 44,
      title: Text(
        name,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColorTokens.accent.withAlpha(14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColorTokens.accent.withAlpha(45)),
        ),
        child: Text(
          license,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColorTokens.accent,
          ),
        ),
      ),
    );
  }
}
