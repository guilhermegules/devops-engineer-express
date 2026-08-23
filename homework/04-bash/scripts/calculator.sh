#!/usr/bin/env bash

add() {
    echo "$1 + $2 = $(( $1 + $2 ))"
}

subtract() {
    echo "$1 - $2 = $(( $1 - $2 ))"
}

multiply() {
    echo "$1 * $2 = $(( $1 * $2 ))"
}

divide() {
    if [[ $2 -eq 0 ]]; then
        echo "Error: division by zero"
        exit 1
    fi
    echo "$1 / $2 = $(( $1 / $2 ))"
}

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <num1> <operator> <num2>"
    echo "Example: $0 5 '+' 3"
    exit 1
fi

NUM1=$1
OPERATOR=$2
NUM2=$3

case "$OPERATOR" in
    +)
        add "$NUM1" "$NUM2"
        ;;
    -)
        subtract "$NUM1" "$NUM2"
        ;;
    \*|x)
        multiply "$NUM1" "$NUM2"
        ;;
    /)
        divide "$NUM1" "$NUM2"
        ;;
    *)
        echo "Error: invalid operator '$OPERATOR'. Supported: + - * /"
        exit 1
        ;;
esac
