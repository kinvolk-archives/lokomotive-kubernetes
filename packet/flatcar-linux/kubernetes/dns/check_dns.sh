print_entries() {
    # TODO: implement pretty print to show the user the entries they should configure
    echo "\nPlease configure the following entries in your DNS provider and run 'terraform apply' again"
    echo $1
    exit 1
}

#echo $JSON

for name in `echo $JSON | jq -r '.[] | .name'`
do
    # check if there are entries for such name, if not ask the user to configrue them
    entries=`getent ahostsv4 $name`
    if [ $? -ne 0 ]; then
        print_entries $JSON
    fi
done

# TODO: verify that existing entries are well configured! (the records are the correct ones)

exit 0
