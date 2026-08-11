import 'package:flutter/material.dart';

import '../../core/routing/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../models/content_record.dart';
import '../shared/content_detail_page.dart';
import '../shared/content_list_page.dart';

/// The three community directories: businesses, organizations and development
/// projects. They share one file because they share one shape — a directory
/// entry with contact details — and splitting them would only mean three
/// near-identical files to keep in step.

/// EKOLI-YEDEN BUSINESS & PROFESSIONAL DIRECTORY.
class BusinessesListPage extends StatelessWidget {
  const BusinessesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentListPage(
      resource: 'businesses',
      basePath: AppRoutes.businesses,
      eyebrow: 'Directory',
      title: 'Businesses & Professionals',
      description:
          'Businesses, trades and professional services run by people of Ekoli-Yeden, at home and '
          'abroad — so the community can find and support its own.',
      emptyTitle: 'The directory is empty',
      emptyMessage:
          'No businesses have been listed yet. If you run a business or practise a profession and '
          'would like to be listed, please get in touch through the contribution page.',
      metaBuilder: (ContentRecord record) {
        final String? category = record.text('category');
        final String? city = record.text('city');
        if (category != null && city != null) return '$category · $city';
        return category ?? city;
      },
    );
  }
}

class BusinessDetailPage extends StatelessWidget {
  const BusinessDetailPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return ContentDetailPage(
      resource: 'businesses',
      identifier: slug,
      basePath: AppRoutes.businesses,
      sectionTitle: 'Businesses',
      detailFields: <DetailField>[
        const DetailField(label: 'Category', key: 'category'),
        const DetailField(label: 'Services', key: 'services'),
        const DetailField(label: 'Owner', key: 'owner_name'),
        const DetailField(label: 'Phone', key: 'phone'),
        const DetailField(label: 'Email', key: 'email'),
        const DetailField(label: 'Website', key: 'website_url'),
        const DetailField(label: 'Address', key: 'address'),
      ],
    );
  }
}

/// ORGANIZATIONS — unions, associations, schools, churches and societies.
class OrganizationsListPage extends StatelessWidget {
  const OrganizationsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentListPage(
      resource: 'organizations',
      basePath: AppRoutes.organizations,
      eyebrow: 'Directory',
      title: 'Organizations',
      description:
          'Unions, associations, societies, schools, churches and other bodies serving the '
          'Ekoli-Yeden community.',
      emptyTitle: 'No organizations listed yet',
      emptyMessage:
          'Organizations will appear here once their details have been supplied and confirmed.',
      metaBuilder: (ContentRecord record) => record.text('organization_type'),
    );
  }
}

class OrganizationDetailPage extends StatelessWidget {
  const OrganizationDetailPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return ContentDetailPage(
      resource: 'organizations',
      identifier: slug,
      basePath: AppRoutes.organizations,
      sectionTitle: 'Organizations',
      detailFields: <DetailField>[
        const DetailField(label: 'Type', key: 'organization_type'),
        const DetailField(label: 'Mission', key: 'mission'),
        const DetailField(label: 'Founded', key: 'founded_year'),
        const DetailField(label: 'Contact', key: 'contact_name'),
        const DetailField(label: 'Phone', key: 'phone'),
        const DetailField(label: 'Email', key: 'email'),
        const DetailField(label: 'Website', key: 'website_url'),
        const DetailField(label: 'Address', key: 'address'),
      ],
    );
  }
}

/// COMMUNITY DEVELOPMENT PORTAL.
///
/// Projects are listed with their funding target, funds raised and progress, so
/// that the community can see where a project actually stands. Those figures
/// come from the project committee's own records — the platform does not
/// estimate them.
class CommunityProjectsListPage extends StatelessWidget {
  const CommunityProjectsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentListPage(
      resource: 'community',
      basePath: AppRoutes.community,
      eyebrow: 'Development',
      title: 'Community Projects',
      description:
          'Development projects in Ekoli-Yeden: what is planned, what is underway, what has been '
          'completed, and how each is progressing.',
      emptyTitle: 'No projects published yet',
      emptyMessage:
          'Community development projects will be listed here with their purpose, committee and '
          'progress once the information has been supplied.',
      metaBuilder: (ContentRecord record) {
        final String? state = record.text('project_status');
        final int? progress = record.number('progress_percent');
        if (state != null && progress != null) return '$state · $progress% complete';
        return state;
      },
    );
  }
}

class CommunityProjectDetailPage extends StatelessWidget {
  const CommunityProjectDetailPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return ContentDetailPage(
      resource: 'community',
      identifier: slug,
      basePath: AppRoutes.community,
      sectionTitle: 'Community Projects',
      detailFields: <DetailField>[
        const DetailField(label: 'Purpose', key: 'purpose'),
        const DetailField(label: 'Location', key: 'location'),
        const DetailField(label: 'Committee', key: 'committee'),
        const DetailField(label: 'Status', key: 'project_status'),
        DetailField(
          label: 'Progress',
          key: 'progress_percent',
          formatter: (dynamic value) => '$value% complete',
        ),
        DetailField(
          label: 'Funding target',
          key: 'funding_target',
          formatter: (dynamic value) => Formatters.currency(value as num?, 'NGN'),
        ),
        DetailField(
          label: 'Funds raised',
          key: 'funds_raised',
          formatter: (dynamic value) => Formatters.currency(value as num?, 'NGN'),
        ),
        DetailField(
          label: 'Started',
          key: 'start_date',
          formatter: (dynamic value) => Formatters.date(value.toString()),
        ),
      ],
    );
  }
}
