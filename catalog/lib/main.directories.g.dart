// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering

// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AppGenerator
// **************************************************************************

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:appforge_catalog/widgets/branded_error_view_use_case.dart'
    as _appforge_catalog_widgets_branded_error_view_use_case;
import 'package:appforge_catalog/widgets/mini_app_preview_use_case.dart'
    as _appforge_catalog_widgets_mini_app_preview_use_case;
import 'package:appforge_catalog/widgets/rolling_greeting_use_case.dart'
    as _appforge_catalog_widgets_rolling_greeting_use_case;
import 'package:widgetbook/widgetbook.dart' as _widgetbook;

final directories = <_widgetbook.WidgetbookNode>[
  _widgetbook.WidgetbookFolder(
    name: 'widgets',
    children: [
      _widgetbook.WidgetbookComponent(
        name: 'BrandedErrorView',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Custom Error',
            builder: _appforge_catalog_widgets_branded_error_view_use_case
                .buildBrandedErrorViewCustomUseCase,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Forbidden (Full)',
            builder: _appforge_catalog_widgets_branded_error_view_use_case
                .buildBrandedErrorViewForbiddenFullUseCase,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Offline (Compact)',
            builder: _appforge_catalog_widgets_branded_error_view_use_case
                .buildBrandedErrorViewOfflineCompactUseCase,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Resting (Compact)',
            builder: _appforge_catalog_widgets_branded_error_view_use_case
                .buildBrandedErrorViewRestingCompactUseCase,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'MiniAppPreview',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Complex App',
            builder: _appforge_catalog_widgets_mini_app_preview_use_case
                .buildMiniAppPreviewComplexUseCase,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Default',
            builder: _appforge_catalog_widgets_mini_app_preview_use_case
                .buildMiniAppPreviewUseCase,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'RollingGreeting',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Custom Style',
            builder: _appforge_catalog_widgets_rolling_greeting_use_case
                .buildRollingGreetingCustomUseCase,
          ),
          _widgetbook.WidgetbookUseCase(
            name: 'Default',
            builder: _appforge_catalog_widgets_rolling_greeting_use_case
                .buildRollingGreetingUseCase,
          ),
        ],
      ),
    ],
  ),
];
