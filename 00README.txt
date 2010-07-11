gen-conference-schedule-table README
                                        2010-07-11 Yamauchi, Hitoshi
                                                   Sunday Researcher

Project page:
        https://code.google.com/p/gen-conference-schedule-table/

Prerequisites:

        ruby 1.8.7
        flydraw

Simple example: (or run the test_draw_conf.sh)
     
  1. creating a fly file

    draw_conf_schedule.rb -i cg_conf_input_example.dat -o test_00.fly

  2. create a gif file from the fly file

    flydraw < test_00.fly > test_00.gif


This shows all the usage of the program.

    draw_conf_schedule.rb -h
