# pg\_hint\_plan 1.9

`pg_hint_plan` makes it possible to tweak PostgreSQL execution plans using
so-called "hints" in SQL comments, like `/*+ SeqScan(a) */`.

PostgreSQL uses a cost-based optimizer, that uses data statistics, not static
rules.  The planner (optimizer) estimates costs of each possible execution
plans for a SQL statement, then executes the plan with the lowest cost.
The planner does its best to select the best execution plan, but it is far
from perfect, since it may not count some data properties, like correlation
between columns.

For more details, please see the various documentations available in the
**docs/** directory:

1. [Description](docs/description.md)
1. [The hint table](docs/hint_table.md)
1. [Installation](docs/installation.md)
1. [Uninstallation](docs/uninstallation.md)
1. [Details in hinting](docs/hint_details.md)
1. [Errors](docs/errors.md)
1. [Functional limitations](docs/functional_limitations.md)
1. [Requirements](docs/requirements.md)
1. [Hints list](docs/hint_list.md)

* * * * *

Copyright (c) 2012-2024, NIPPON TELEGRAPH AND TELEPHONE CORPORATION
