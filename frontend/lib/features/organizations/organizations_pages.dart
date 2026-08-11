/// ORGANIZATIONS.
///
/// The screens live in `features/businesses/directory_pages.dart` alongside the
/// other two directories, because all three share one shape — a directory entry
/// with contact details — and keeping them together means one place to change
/// when that shape changes. This file exists so the section is still reachable
/// from its own feature directory.
library;

export '../businesses/directory_pages.dart'
    show OrganizationsListPage, OrganizationDetailPage;
