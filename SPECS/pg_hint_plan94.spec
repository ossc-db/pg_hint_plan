# SPEC file for pg_hint_plan
# Copyright(C) 2012-2019 NIPPON TELEGRAPH AND TELEPHONE CORPORATION

%define _pgdir   /usr/pgsql-9.4
%define _bindir  %{_pgdir}/bin
%define _libdir  %{_pgdir}/lib
%define _datadir %{_pgdir}/share
%if "%(echo ${MAKE_ROOT})" != ""
  %define _rpmdir %(echo ${MAKE_ROOT})/RPMS
  %define _sourcedir %(echo ${MAKE_ROOT})
%endif

## Set general information for pg_hint_plan.
Summary:    Optimizer hint for PostgreSQL 9.4
Name:       pg_hint_plan94
Version:    1.1.7
Release:    1%{?dist}
License:    BSD
Group:      Applications/Databases
Source0:    %{name}-%{version}.tar.gz
#URL:        http://example.com/pg_hint_plan/
BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-%(%{__id_u} -n)
Vendor:     NIPPON TELEGRAPH AND TELEPHONE CORPORATION

## We use postgresql-devel package
BuildRequires:  postgresql94-devel
Requires:  postgresql94-libs

## Description for "pg_hint_plan"
%description
pg_hint_plan provides capability to force arbitrary plan to PostgreSQL' planner
to optimize queries by hand directly.

If you have query plan better than which PostgreSQL chooses, you can force your
plan by adding special comment block with optimizer hint before the query you
want to optimize.  You can control scan method, join method, join order, and
planner-related GUC parameters during planning.

Note that this package is available for only PostgreSQL 9.4.

## pre work for build pg_hint_plan
%prep
PATH=/usr/pgsql-9.4/bin:$PATH
if [ "${MAKE_ROOT}" != "" ]; then
  pushd ${MAKE_ROOT}
  make clean %{name}-%{version}.tar.gz
  popd
fi
if [ ! -d %{_rpmdir} ]; then mkdir -p %{_rpmdir}; fi
%setup -q

## Set variables for build environment
%build
PATH=/usr/pgsql-9.4/bin:$PATH
make USE_PGXS=1 %{?_smp_mflags}

## Set variables for install
%install
rm -rf %{buildroot}
make install DESTDIR=%{buildroot}

%clean
rm -rf %{buildroot}

%files
%defattr(0755,root,root)
%{_libdir}/pg_hint_plan.so
%defattr(0644,root,root)
%{_datadir}/extension/pg_hint_plan--1.1.2--1.1.3.sql
%{_datadir}/extension/pg_hint_plan--1.1.3--1.1.4.sql
%{_datadir}/extension/pg_hint_plan--1.1.4--1.1.5.sql
%{_datadir}/extension/pg_hint_plan--1.1.5--1.1.6.sql
%{_datadir}/extension/pg_hint_plan--1.1.6--1.1.7.sql
%{_datadir}/extension/pg_hint_plan--1.1.7.sql
%{_datadir}/extension/pg_hint_plan.control

# History of pg_hint_plan.
%changelog
* Tue Nov 13 2018 Kyotaro Horiguchi
- Improvement of debug message emission.
* Fri Jun 08 2018 Kyotaro Horiguchi
- Fixed a crash bug.
* Thu Jul 27 2017 Kyotaro Horiguchi
- Fixed a crash bug.
* Fri May 19 2017 Kyotaro Horiguchi
- Fixed a crash bug.
* Thu Dec 22 2014 Kyotaro Horiguchi
- Bug fix related to pl/pgsql.
* Thu Dec 17 2014 Kyotaro Horiguchi
- Support 9.4. New rev 1.1.2.
* Thu Dec 17 2014 Kyotaro Horiguchi
- Support 9.4. New rev 1.1.2.
* Mon Sep 02 2013 Takashi Suzuki
- Initial cut for 1.1.0
* Mon Sep 24 2012 Shigeru Hanada <shigeru.hanada@gmail.com>
- Initial cut for 1.0.0

