import 'package:flutter/material.dart';

import '../database_helper.dart';
import 'encomendas_screen.dart';
import 'login_screen.dart';
import 'moradores_screen.dart';
import 'porteiros_screen.dart';

class DashboardScreen extends StatelessWidget {
  static const routeName = '/dashboard';

  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final porteiro = ModalRoute.of(context)!.settings.arguments as Porteiro?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel Principal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () {
              Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (porteiro != null)
              Text(
                'Bem-vindo, ${porteiro.nome} (${porteiro.periodo})',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _DashboardCard(
                    icon: Icons.inventory_2,
                    title: 'Gestão de Encomendas',
                    subtitle: 'Registrar entrada, dar baixa e histórico',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => EncomendasScreen(
                            porteiro: porteiro,
                          ),
                        ),
                      );
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.people,
                    title: 'Gestão de Moradores',
                    subtitle: 'Cadastrar, listar e excluir moradores',
                    onTap: () {
                      Navigator.of(context)
                          .pushNamed(MoradoresScreen.routeName);
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.admin_panel_settings,
                    title: 'Gestão de Porteiros',
                    subtitle: 'Cadastrar, listar e excluir porteiros',
                    onTap: () {
                      Navigator.of(context)
                          .pushNamed(PorteirosScreen.routeName);
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.picture_as_pdf,
                    title: 'Exportar Relatório (PDF)',
                    subtitle: 'Gerar e salvar relatório de encomendas',
                    onTap: () {
                      Navigator.of(context)
                          .pushNamed(EncomendasScreen.routeName);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
