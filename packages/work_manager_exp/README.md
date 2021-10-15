# work_manager_exp

Work manager experiment:
- A service runs in a single background isolate
- Every 15 mn, perform some background operations
  - perform a long http request
  - perform a long sqlite transaction

## Setup

For Android you must create the project:

```shell
flutter create --platforms android .
```
