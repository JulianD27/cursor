enum AppSection { dashboard, gases, ventilacion, alertas }

extension AppSectionX on AppSection {
  String get label => switch (this) {
        AppSection.dashboard => 'Dashboard',
        AppSection.gases => 'Monitoreo de Gases',
        AppSection.ventilacion => 'Ventilación',
        AppSection.alertas => 'Alertas',
      };
}

