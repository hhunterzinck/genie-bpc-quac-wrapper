# GENIE BPC Quality Assurance Checklist Wrapper

Wrapper for the Quality Assurance Checklist to monitor requested upload entities and notify points of contact upon modification and error report production.  Designed to be run with Service Catalog scheduled jobs.  

## Installation

Clone this repository and navigate to the directory:
```
git clone git@github.com:hhunterzinck/genie-bpc-quac-wrapper.git
cd genie-bpc-quac-wrapper/
```

Build the Docker containter:
```
docker build -t genie-bpc-quac-wrapper .
```

## Synapse credentials

Cache your Synapse personal access token (PAT) as an environmental variable:
```
export SYNAPSE_AUTH_TOKEN={your_personal_access_token_here}
```

## Usage 

To display the command line interface:
```
docker run -e SYNAPSE_AUTH_TOKEN=$SYNAPSE_AUTH_TOKEN --rm genie-bpc-quac-wrapper -h
```

The command line interface will display as follows:
```
usage: genie-bpc-quac-wrapper.R [-h] [-v VALUE] [-u {day,hour}] [-t] [-d]

optional arguments:
  -h, --help            show this help message and exit
  -v VALUE, --value VALUE
                        Number of time units (default: 1)
  -u {day,hour}, --unit {day,hour}
                        Time unit (default: day)
  -t, --testing         Run on synthetic test uploads
  -d, --verbose         Verbose reporting on script progress to the user
```

Example run: 
```
docker run -e SYNAPSE_AUTH_TOKEN=$SYNAPSE_AUTH_TOKEN --rm genie-bpc-quac-wrapper -d 
```
