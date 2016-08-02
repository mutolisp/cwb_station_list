#!/usr/bin/env sh

case "$1" in
    "-c")
        # 取代半型空白
        sed -i ''  's/ //g' $2
        # 取代全形空白
        sed -i ''  's/　//g' $2
        echo "clean up done!"
        ;;
        
    "-d")
        # 把 YYYY/mm/dd 改成 ISO8601 格式(YYYY-mm-dd) 
        sed -i '' 's/\//-/g' $2
        echo "substitution done!"
        ;;
        
    *)
        echo "Usage: cleandata.sh {-c|-d} filename"
        echo "清理資料，把全/半形空白取代並且整理日期為 ISO 8601 格式(YYYY-mm-dd)"
        ;;
esac
