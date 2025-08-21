setfont ter-v18b
echo "############## WELCOME TO THE ARCH INSTALLER ##############"
echo "install disk: ${1}"
if [ -z "$1" ]; then
    echo "error: provide disk to insstall"
    exit 1
fi


