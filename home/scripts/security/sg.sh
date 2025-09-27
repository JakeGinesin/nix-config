semgrep --config=p/cwe-top-25 --config=p/owasp-top-ten --config=/home/synchronous/extras/semgrep-rules --exclude '*example*' --exclude '*test*' --severity ERROR -- .
