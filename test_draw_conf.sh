#!/bin/sh -x
#
# simple unit test and also example of usage
# Copyright (C) 2010 Yamauchi, Hitoshi
#

DRAW_CONF_SCHEDULE=draw_conf_schedule.rb
FLYDRAW=flydraw
IMAGEVIEWER=display

#
# test_00
#
TEST00_BASE=test_00

rm -f ${TEST00_BASE}.fly ${TEST00_BASE}.gif

./${DRAW_CONF_SCHEDULE} -i cg_conf_input_example.dat -o ${TEST00_BASE}.fly
${FLYDRAW} < ${TEST00_BASE}.fly > ${TEST00_BASE}.gif
${IMAGEVIEWER} ${TEST00_BASE}.gif



# clean up
rm -f ${TEST00_BASE}.fly ${TEST00_BASE}.gif