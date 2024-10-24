# Tests

## unit-tests.sh

Currently broken. Unit tests make programming so tedious that I'm hoping end-to-end tests will be enough.

## build-tests.sh

I'm not sure that this needs to be kept either.

## e2e-tests.sh

This script starts the end-to-end tests. Tests are run using `cmdline-player`, installed during `sudo make install`. 

Test output is saved in `e2e-logs` in files with format as:

```none
2020-06-05-1591367000_test-2_GOOD_1.0000.log
               ^           ^  ^   ^  
    unix timestamp         |  |   |
                  Test number |   |
                   CRM114 status  |
                            CRM114 confidence (pR)
```

In CRM114 we use OSB Classification to train good and bad output from tests.

About CRM 114 confidence (pR):

> CRM114 classifiers are generally set up to give pR values in this scale; experimental
> classifiers may need to be adjusted to get their typical results into the following ranges:
> 
> * pR values above +100 signify “high chance this text is a member of this class”
> * pR values between +100 and +10 signify “moderate chance this text is a member of
>   this class”
> * pR values between +10 and ­-10 signify “unsure” (and typically should be retrained if
>   using either SSTTT or DSTTT training.
> * pR values between ­-10 and ­-100 signify “moderate chance this text is not a member of
>   this class”
> * pR values of below ­-100 signify “high chance this text is not a member of this class”

### Usage texts

Sanity checks for usage texts. CSS files were created with:

```bash
# Must use bash, not zsh, for these:

# Create css files
for i in build create delete exec get unknown; do crm learn.crm ${i^^}_USAGE <<<$(:); done

# Train css files
for i in build create delete exec get; do crm learn.crm ${i^^}_USAGE <<<$(mok ${i} -h); done

```

The CSS files are matched to actual `mok command -h` usage in `usage-checks.sh`.

Output from `usage-checks.sh`:

```none
GOOD - CRM114 thinks output from 'mok build -h' is BUILD_USAGE.
GOOD - CRM114 thinks output from 'mok create -h' is CREATE_USAGE.
GOOD - CRM114 thinks output from 'mok delete -h' is DELETE_USAGE.
GOOD - CRM114 thinks output from 'mok exec -h' is EXEC_USAGE.
GOOD - CRM114 thinks output from 'mok get -h' is GET_USAGE.
```
