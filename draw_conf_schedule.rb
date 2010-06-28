#! /usr/bin/ruby
#
# draw_conf_schedule.rb
# Copyright (C) 2010 Yamauchi, Hitoshi
#

#------------------------------------------------------------
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#------------------------------------------------------------

#------------------------------------------------------------
# TODO:
# - generate a date line
#------------------------------------------------------------

require 'getoptlong.rb'
require 'date'

# assertion
require 'runit/assert'
include RUNIT::Assert

#------------------------------------------------------------
# constants
#------------------------------------------------------------
DRAW_CONF_SCHEDULE_VERSION = "0.1.0"
MAX_CONF_NAME_LENGTH       = 8
COPYRIGHT_STR              = "Copyright (C) 2010 Yamauchi, Hitoshi. "
VERSION_STR                = "draw_conf_schedule.rb version " + DRAW_CONF_SCHEDULE_VERSION

# size constants: see draw_conf_schedule_table_length_chart.pdf
#
# figure margin (pixels)
#  LR_MARGIN: Left margin = Right margin
#  TB_MARGIN: Top margin = bottom margin
LR_MARGIN  = 10
TB_MARGIN  = 10

CONF_NAME_LABEL_WIDTH     = 120
CONF_NAME_LABEL_TOPMARGIN = 12

BAR_TOP_MARGIN     = 20
BAR_LABEL_T_MARGIN = 6
BAR_LABEL_B_MARGIN = 4
BAR_HEIGHT         = 1
DATE_LABEL_HEIGHT  = 8


# Marker size
TRIANGLE_SIZE = 7
CIRCLE_SIZE   = 8
SQUARE_SIZE   = 7

# pixel size of date label
# This is the max width (2010/01/01-2010/01/02 format), for safety
DOUBLE_DATE_WIDTH = 126

# conference tabel html map name (<map name='HTML_CONF_TABLE_MAP_NAME'>)
HTML_CONF_TABLE_MAP_NAME = 'cg_conf_table_imagemap'
HTML_CONF_TABLE_MAP_DEFAULT_FILENAME = 'cg_conf_table_imagemap.html'

#
# Universal Colors
#
# Color Barrier Free
# http://jfly.iam.u-tokyo.ac.jp/color/index.html
# Color Universal Design (CUD)
# - How to make figures and presentations that are friendly to Colorblind people -
#
# Based on sRGB color chart
#
# (Colors are string here)
RED       = [235,  97,  16]
BLUE      = [ 49, 106, 179]
GREEN     = [  6, 175, 122]
ORANGE    = [245, 161,   0]
LIGHTBLUE = [229, 249, 237]

BAR_COLOR              = BLUE
DEADLINEMARK_COLOR     = RED
CONFMARK_COLOR         = GREEN
NOTIFICATIONMARK_COLOR = ORANGE

# current implementation: one pixel is one day
# DAY_PER_PIXEL = 1
# PIXEL_PER_DAY = 1 / DAY_PER_PIXEL

#------------------------------------------------------------
# help
#------------------------------------------------------------
def print_help()
  $stderr.print <<"HELP"
usage: draw_conf_schedule.rb [-h|--help] [-V|--version] [-v|--verbose] [[-i|--infile] infile.dat] [[-o|--outfile] outfile.png] [[-I|--image-map-file] imagemap_outfile], [[-d|--textdeadline] {0|1}] [[-c|--textconference] {0|1}] [[-n|--textnotification] {0|1} [[-m|--month-name] {0|1}]

draw conference schedule image from conference data.
  -h, --help            output this help.
  -V, --version         show version.
  -v, --verbose         verbose mode.
  -i, --infile          input filename
  -o, --outfile         output image filename
  -I, --image-map-file  image map output filename (default: cg_conf_table_imagemap.html)

Text on/off switch
  -d, --textdeadline      [0|1] deadline     date text 0...off, 1...on, (default:1)
  -c, --textconference    [0|1] conference   date text 0...off, 1...on, (default:1)
  -n, --textnotification  [0|1] notification date text 0...off, 1...on, (default:1)

Text format switch
  -m, --month-name        [0|1] use month name format. (e.g, Jan/01)

CG conf input data Example
-----
#
# conference item
# COMMAND Conf name  conf time                deadline      notification
#
CONFITEM  EGSR2010   2010/06/28-2010/06/30    2010/04/09    2010/05/14
CONFITEM  HPG2010    2010/06/25-2010/06/27    2010/04/09    2010/05/08
CONFITEM  SIGGASIA   2010/12/15-2010/12/18    2010/05/11    <unknown>
#
# date line item
# COMMAND date       label
DATELINE  2010/05/11 11th_May
-----
HELP
  $stderr.print COPYRIGHT_STR + "\n"
  $stderr.print VERSION_STR   + "\n"
end

#------------------------------------------------------------
# verbose output
#------------------------------------------------------------
def verboseprint(mes)
  if $OPT_VERBOSE then
    $stderr.print mes
  end
end

#------------------------------------------------------------
# class One_conf_entry
#------------------------------------------------------------
class One_conf_entry
  # accessor
  attr_accessor :conf_name
  attr_accessor :conf_start_date
  attr_accessor :conf_end_date
  attr_accessor :conf_deadline_date
  attr_accessor :conf_notification_date

  # constructor
  def initialize()
    clear()
  end

  # clear
  def clear()
    @conf_name              = ""

    # [year, month, date]
    @conf_start_date        = nil
    @conf_end_date          = nil
    @conf_deadline_date     = nil
    @conf_notification_date = nil
  end

  # get Date object of year, month, day
  #
  # \param _ymd_str year/month/day string. e.g., 2010/01/02
  def get_date_from_string(_ymd_str)
    begin
      if _ymd_str.length != 10
        raise RuntimeError.new("illegal year/month/day string [" +
                               _ymd_str + "], e.g., 2010/01/02")
      end
      ymd_array = _ymd_str.split("/")
      return Date::new(ymd_array[0].to_i, ymd_array[1].to_i, ymd_array[2].to_i)
    end
  end

  # set an entry
  def set_entry(_conf_name,
                _conf_start_date,
                _conf_end_date,
                _deadline_date,
                _conf_notification_date)
    begin
      @conf_name          = _conf_name

      # [year, month, date]
      @conf_start_date    = get_date_from_string(_conf_start_date)
      @conf_end_date      = get_date_from_string(_conf_end_date)
      @conf_deadline_date = get_date_from_string(_deadline_date)

      # conf_notification_date could be "<unknown>"
      if _conf_notification_date != "<unknown>"
        @conf_notification_date  = get_date_from_string(_conf_notification_date)
      end

      check_entry()

    end
  end

  #
  # check the entry consistency
  # if not raise exception
  #
  def check_entry()
    # conference name
    if @conf_name.empty?
      raise RuntimeError.new("empty conference name\n")
    end
    if @conf_name.length > MAX_CONF_NAME_LENGTH
      raise RuntimeError.new("conference short name is too long: " +
                             @conf_name + "\n")
    end

    # conference time constraint
    if @conf_start_date > @conf_end_date
      raise RuntimeError.new("inconsistent conference date. " +
                             "start date > end date.\n")
    end

    if @conf_deadline_date >= @conf_start_date
      raise RuntimeError.new("inconsistent conference date. " +
                             "deadline > start date.\n")
    end

    if !(@conf_notification_date.nil?)
      if @conf_notification_date <= @conf_deadline_date
        raise RuntimeError.new("inconsistent date. notification <= deadline.\n")
      end
      if @conf_notification_date >= @conf_start_date
        raise RuntimeError.new("inconsistent date. notification >= conf start date.\n")
      end
    end
  end

  # printout for debug
  def printout()
    $stderr.print "[" + @conf_name + "]\n"
    $stderr.print "Start        [" + @conf_start_date.   to_s + "]\n"
    $stderr.print "End          [" + @conf_end_date.     to_s + "]\n"
    $stderr.print "Deadline     [" + @conf_deadline_date.to_s + "]\n"
    if !(@conf_notification_date.nil?)
      $stderr.print "Notification [" +
        @conf_notification_date.to_s + "]\n"
    else
      $stderr.print "Notification [<unknown>]\n"
    end
  end
end

#------------------------------------------------------------
# class Draw_conf_schedule
#------------------------------------------------------------
class Draw_conf_schedule
  #
  # constructor
  #
  def initialize()
    # @foo is instance variable

    # current number of line
    @current_n_line = 0

    # input file name
    @infilename   = "-";
    # output file name
    @outfilename  = "-";
    # image map output filename
    @imagemapfilename = HTML_CONF_TABLE_MAP_DEFAULT_FILENAME

    # input file stream
    @infile  = $stdin;
    # output file stream
    @outfile = $stdout;
    # image map output filename
    @imagemapfile = nil

    @conf_entry_array = []

    # not constant, this depends on text mode
    @grid_height      = 0

    # year range
    @min_year = nil;
    @max_year = nil;

    # canvas/figure range
    @figure_width  = nil;
    @figure_height = nil;
    @image_width   = nil;
    @image_height  = nil;


  end

  #----------------------------------------------------------------------
  # parse the data file
  #----------------------------------------------------------------------
  #
  # check the hedaer line
  #
  # read one line and check the header, if not match the header, raise
  # IOException
  #
  def check_header()
    begin
      hline = @infile.gets().strip
      @current_n_line += 1

      hlarray = hline.split

      # check the header exists
      if hlarray.length != 3
        raise IOError.new("No conf data header. Is it confdata file? (#! confdata ver)")
      end

      # check it has #! confdata
      if (hlarray[0] != "#!") || (hlarray[1] != "confdata")
        raise IOError.new("Illegal conf data header. Is it confdata file? " +
                          "(#! confdata ver)\n")
      end

      # check the version "2"
      if hlarray[2] != "2"
        raise IOError.new("Unsupported version (" + hlarray[2] +
                          "). Current version is 1\n")
      end

    end
  end


  #
  # parse one conference item line
  #
  # \param _confitem_line conference item line
  def parse_one_conf_item(_confitem_line)
    begin
      cdata = _confitem_line.split
      if cdata.length != 5 then
        raise RuntimeError.new("conference data line doesn't have enough information\n")
      end

      assert(cdata[0] == 'CONFITEM',
             'Internal error. the command must be CONFITEM here')

      conf_name              = cdata[1]
      conf_start_end_date    = cdata[2].split("-")
      conf_deadline_date     = cdata[3]
      conf_notification_date = cdata[4]

      conf_entry = One_conf_entry.new()
      conf_entry.set_entry(conf_name,
                           conf_start_end_date[0], conf_start_end_date[1],
                           conf_deadline_date,
                           conf_notification_date)

      # append an entry
      @conf_entry_array << conf_entry;
    end
  end

  #
  # parse one dateline item line
  #
  # \param _dateitem_line date item line
  def parse_one_dateline_item(_dateitem_line)
    begin
      ddata = _dateitem_line.split
      if ddata.length != 3 then
        raise RuntimeError.new("illegal conference dateline line\n")
      end

      assert(ddata[0] == 'DATELINE',
             'Internal error. the command must be DATELINE here')

      # append an entry
      # @dateline_entry_array << conf_entry;
    end
  end

  #
  # parse one line
  #
  def parse_one_line(_line)
    begin

      # comment
      if (_line =~ /^#/) || (_line =~ /^$/)
        return
      end
      cdata = _line.split

      if cdata.length < 3
        raise RuntimeError.new("illegal data line [" + _line + "]\n")
      end

      # command
      if cdata[0] == 'CONFITEM'
        parse_one_conf_item(_line)
      elsif cdata[0] == 'DATELINE'
        parse_one_dateline_item(_line)
      else
        raise RuntimeError.new("Unknown command [" + cdata[0] + "]\n")
      end
    end
  end

  #
  # parse a file
  #
  def parse_file()
    begin
      # check the header
      check_header()

      # read the rest of the data
      while line = @infile.gets()
        @current_n_line += 1
        # delete (head & tail) white space
        ll = line.strip

        # process one line
        parse_one_line(ll);
      end

    rescue
      # `$!' has the last exception object
      print "Error! : " + $!.message + " at line ", @current_n_line, "\n"
      print "--- Backtrace ---\n"
      $!.backtrace.each do |tracemes|
        print tracemes + "\n"
      end
    end
  end

  # sort entry with deadline
  def sort_by_deadline()
    begin
      tmp = @conf_entry_array.sort {
        |a, b|
        a.conf_deadline_date <=> b.conf_deadline_date
      }

      @conf_entry_array = tmp

      if $OPT_VERBOSE
        print "----- BEGIN entries sorted by deadline -----\n"
        printout()
        print "----- END   entries sorted by deadline -----\n"
      end
    end
  end


  #
  # print for debug
  #
  def printout()
    begin
      @conf_entry_array.each{
        |x|
        x.printout()
      }
    end
  end


  #----------------------------------------------------------------------
  # export the fly data
  #----------------------------------------------------------------------

  #
  # get the min deadline
  #
  # assumption data exists.
  #
  # \param _conf_entry_array conference data array (One_conf_entry[])
  # \return minimum deadline time (the first conference deadline.)
  #
  def get_min_deadline(_conf_entry_array)
    begin
      if _conf_entry_array.length == 0 then
        raise RuntimeError.new("empty conference data array.\n")
      end

      ret = _conf_entry_array.min {
        |a, b|
        a.conf_deadline_date <=> b.conf_deadline_date
      }

      return ret
    end
  end

  #
  # get the max conf date
  #
  # assumption data exists.
  #
  # \param _conf_entry_array conference data array (One_conf_entry[])
  # \return maximum conf date time (the last conference end.)
  #
  def get_max_confend(_conf_entry_array)
    begin
      if _conf_entry_array.length == 0 then
        raise RuntimeError.new("empty conference data array.\n")
      end

      ret = _conf_entry_array.max {
        |a, b|
        a.conf_end_date <=> b.conf_end_date
      }

      return ret
    end
  end


  #
  # initialize canvas size
  #
  def init_canvas_size()
    begin
      if $OPT_TEXTNOTIFICATION == '0' then
        @grid_height   = 30
      else
        @grid_height   = 40
      end

      min_deadline = get_min_deadline(@conf_entry_array);
      max_conf_end = get_max_confend(@conf_entry_array);

      @min_year = min_deadline.conf_deadline_date.year
      @max_year = (max_conf_end.conf_end_date + DOUBLE_DATE_WIDTH).year

      #       print "DEBUG ---------- min " + @min_year.to_s + ", max year " +
      #         @max_year.to_s + "\n"

      @figure_width  =
        ((Date::new(@max_year + 1, 1, 1) - Date::new(@min_year, 1, 1)).to_i) +
        CONF_NAME_LABEL_WIDTH
      # the first grid is for {year, month} label, therefore, + 1
      @figure_height = @grid_height * (@conf_entry_array.length + 1)
      @image_width   = @figure_width  + (2 * LR_MARGIN)
      @image_height  = @figure_height + (2 * TB_MARGIN)
    end
  end



  #----------------------------------------------------------------------
  # fly output
  #----------------------------------------------------------------------
  #
  # fly output header
  #
  def fly_out_header()
    begin
      @outfile.print "#\n" +
        "# conference schedule table\n" +
        "# "  + COPYRIGHT_STR + "\n" +
        "# "  + VERSION_STR   + "\n" +
        "#\n" +
        "new\n"

      @outfile.print "size " + @image_width.to_s + ", " + @image_height.to_s + "\n"
      # fill color at (1, 1) with 255, 255, 255
      @outfile.print "fill 1, 1, 255, 255, 255\n"
    end
  end

  #
  # fly output text (black only)
  #
  # \param _x x     position of the text
  # \param _y y     position of the text
  # \param _font    font size {'small','medium',..,} defined by fly
  # \param _text    print out text
  # \param _comment comment in the comment line of this output
  #
  def fly_out_text(_x, _y, _font, _text, _comment)
    begin
      @outfile.print "# text " + _comment + ": " +
        "(" + _x.to_s + ", " + _y.to_s + ") [" + _text + "]\n"
      @outfile.print "string 0,0,0," + _x.to_s + "," + _y.to_s +
        "," + _font + "," + _text + "\n"
    end
  end

  #
  # fly output line
  #
  # \param _r       color Red
  # \param _g       color Green
  # \param _b       color Blue
  # \param _x1      line origin x
  # \param _y1      line origin y
  # \param _x2      line destination x
  # \param _y2      line destination y
  # \param _comment comment
  #
  def fly_out_line(_r, _g, _b, _x1, _y1, _x2, _y2, _comment)
    begin
      @outfile.print "# line " + _comment + ": "   +
        "(" + _x1.to_s + ", " + _y1.to_s + ")-(" +
        _x2.to_s + ", " + _y2.to_s + "), RGB ("    +
        _r.to_s  + ", " + _g.to_s  + ", " + _b.to_s  + ")\n"
      @outfile.print "line " + _x1.to_s + "," + _y1.to_s + "," +
        _x2.to_s + "," + _y2.to_s + "," +
        _r.to_s  + "," + _g.to_s  + "," + _b.to_s  + "\n"
    end
  end


  #
  # fly output entry grid
  #
  def fly_out_entry_grid()
    begin
      # @figure_width

      x1s = 0.to_s
      x2s = @image_width.to_s
      item = 1
      while item <= @conf_entry_array.length
        y1s = ((item    ) * @grid_height + TB_MARGIN).to_s
        y2s = ((item + 1) * @grid_height + TB_MARGIN).to_s

        rs = LIGHTBLUE[0].to_s
        gs = LIGHTBLUE[1].to_s
        bs = LIGHTBLUE[2].to_s

        @outfile.print "frect " + x1s + "," + y1s + "," +
          x2s + "," + y2s + "," + rs + "," + gs + "," + bs + "\n"

        item = item + 2
      end
    end
  end

  #
  # fly output month grid
  #
  def fly_out_month_grid()
    begin
      year_range = Range.new(@min_year, @max_year)
      orig_date  = get_origin_date()
      year_x     = LR_MARGIN + CONF_NAME_LABEL_WIDTH
      year_y     = TB_MARGIN + @grid_height
      for year in year_range
        cur_ydate  = Date::new(year, 1, 1)
        cur_year_x = year_x + (cur_ydate - orig_date).to_i
        # flydraw command is "text", but fly is "string"

        # year label
        fly_out_text(cur_year_x, year_y - @grid_height, 'small', year.to_s, 'text year')

        # year line
        fly_out_line(0, 0, 0, cur_year_x, year_y - (@grid_height / 2),
                     cur_year_x, year_y + @figure_height, 'year')

        # month Jan, Jun. + 4 is small margin for text
        fly_out_text(cur_year_x + 4, year_y - (@grid_height / 2), 'small',
                     'Jan', 'month Jan')
        jun_date = Date::new(year, 6, 1)
        jun_x    = year_x + (jun_date - orig_date).to_i
        fly_out_text(jun_x + 4, year_y - (@grid_height / 2), 'small',
                     'Jun', 'month Jun')

        month_range = Range.new(2, 12)
        for month in month_range
          month_date = Date::new(year, month, 1)
          x = year_x + (month_date - orig_date).to_i
          fly_out_line(200, 200, 200, x, year_y - (@grid_height / 2),
                       x, year_y + @figure_height, 'month ' + month.to_s)
        end
      end
    end
  end

  #
  # fly output triangle
  #
  # \param _rgb   color RGB array
  # \param _cx    triangle center x
  # \param _cy    triangle center y
  # \param _size  triangle height
  #
  def fly_out_triangle(_rgb, _cx, _cy, _size)
    begin
      rs = _rgb[0].to_s
      gs = _rgb[1].to_s
      bs = _rgb[2].to_s

      # (x+0.99).to_i = floor(x+0.99)
      p1_x = (_cx - (Math.sqrt(3) * (_size / 3) + 0.99)).to_i.to_s
      p1_y = (_cy + (_size / 3)).to_i.to_s

      p2_x = (_cx + (Math.sqrt(3) * (_size / 3) + 0.99).to_i).to_s
      p2_y = (_cy + (_size / 3)).to_i.to_s

      p3_x = (_cx).to_i.to_s
      p3_y = (_cy - ((2 * _size) / 3)).to_i.to_s

      @outfile.print "fpoly " + rs + "," + gs + "," + bs + "," +
        p1_x + "," + p1_y + "," +
        p2_x + "," + p2_y + "," +
        p3_x + "," + p3_y +
        "\n"
    end
  end

  #
  # fly output circle
  #
  # \param _rgb   color RGB array
  # \param _cx    circle center x
  # \param _cy    circle center y
  # \param _d     circle diameter (pixels)
  #
  def fly_out_circle(_rgb, _cx, _cy, _d)
    begin
      rs  = _rgb[0].to_s
      gs  = _rgb[1].to_s
      bs  = _rgb[2].to_s
      cxs = _cx.to_s
      cys = _cy.to_s
      ds  = _d.to_s

      @outfile.print "fcircle " + cxs + "," + cys + "," + ds + "," +
        rs + "," + gs + "," + bs + "\n"
    end
  end

  #
  # fly output square
  #
  # \param _rgb   color RGB array
  # \param _cx    square center x
  # \param _cy    square center y
  # \param _d     square height (pixels)
  #
  def fly_out_square(_rgb, _cx, _cy, _d)
    begin
      rs  = _rgb[0].to_s
      gs  = _rgb[1].to_s
      bs  = _rgb[2].to_s

      x1 = _cx - _d/2
      y1 = _cy - _d/2
      x2 = x1 + _d
      y2 = y1 + _d

      x1s = x1.to_s
      y1s = y1.to_s
      x2s = x2.to_s
      y2s = y2.to_s
      cxs = _cx.to_s
      cys = _cy.to_s
      ds  = _d.to_s

      @outfile.print "frect " + x1s + "," + y1s + "," + x2s + "," + y2s + "," +
        rs + ',' + gs + "," + bs + "\n"
    end
  end

  #
  # fly output range bar and triangle
  #
  def fly_out_range_bar_triangle(_x1, _y1, _x2, _y2)
    begin
      x1 = _x1.to_s
      y1 = _y1.to_s
      x2 = _x2.to_s
      y2 = (_y2 + BAR_HEIGHT).to_s
      bar_rs = BAR_COLOR[0].to_s
      bar_gs = BAR_COLOR[1].to_s
      bar_bs = BAR_COLOR[2].to_s

      # bar
      @outfile.print "frect " + x1 + "," + y1 + "," + x2 + "," + y2 + "," +
        bar_rs + "," + bar_gs + "," + bar_bs + "\n"

      # deadline
      fly_out_triangle(DEADLINEMARK_COLOR, x1.to_i, y1.to_i, TRIANGLE_SIZE)

      # conf date
      fly_out_square(CONFMARK_COLOR, x2.to_i, y2.to_i, SQUARE_SIZE)

    end
  end

  #
  # get formatted deadline date
  #
  def get_format_deadline_date(_conf_entry)
    begin
      if $OPT_MONTH_NAME == '1' then
        date_format = '%b/%d'
      else
        date_format = '%m/%d'
      end

      ret = _conf_entry.conf_deadline_date.strftime(date_format)
      return ret
    end
  end

  #
  # get formatted notification date
  #
  def get_format_notification_date(_conf_entry)
    begin
      if $OPT_MONTH_NAME == '1' then
        date_format = '%b/%d'
      else
        date_format = '%m/%d'
      end

      ret = _conf_entry.conf_notification_date.strftime(date_format)
      return ret
    end
  end

  #
  # get formatted conference dates
  #
  def get_format_conf_date(_conf_entry)
    begin
      if $OPT_MONTH_NAME == '1' then
        date_format = '%b/%d'
      else
        date_format = '%m/%d'
      end

      ret = _conf_entry.conf_start_date.strftime(date_format)

      if _conf_entry.conf_start_date == _conf_entry.conf_end_date then
        # one day conference
        return ret
      end

      # not one day
      ret = ret + '-'

      if _conf_entry.conf_start_date.month == _conf_entry.conf_end_date.month then
        # the same month
        ret = ret + _conf_entry.conf_end_date.strftime('%d')
        return ret
      else
        # not the same month
        ret = ret + _conf_entry.conf_end_date.strftime(date_format)
        return ret
      end
    end
  end

  #
  # get calender origin date
  # \return origin date as Date's instance
  def get_origin_date()
    begin
      return Date::new(@min_year, 1, 1)
    end
  end

  #
  # get conference label position
  # \param  _entry_orig_y current entry left up's y position
  # \return [x, y] label entry position
  #
  def get_conf_label_position(_entry_orig_y)
    begin
      x = LR_MARGIN
      y = _entry_orig_y + CONF_NAME_LABEL_TOPMARGIN
      return [x, y]
    end
  end

  #
  # get date coordinate on the bar
  # \param  _entry_orig_y current entry left up's y position
  # \param  _date  date
  # \return [x, y] date coordinate
  #
  def get_bar_date_position(_entry_orig_y, _date)
    begin
      orig_date     = get_origin_date()
      day_from_orig = (_date - orig_date).to_i
      day_x         = LR_MARGIN + CONF_NAME_LABEL_WIDTH + day_from_orig
      day_y         = _entry_orig_y + BAR_TOP_MARGIN

      return [day_x, day_y]
    end
  end

  #
  # fly output conference entry
  #
  def fly_out_all_conf_entry()
    begin
      entry_orig_y = TB_MARGIN + @grid_height

      for conf_entry in @conf_entry_array
        #------------------------------------------------------------
        # conference name
        #------------------------------------------------------------
        label_xy = get_conf_label_position(entry_orig_y)
        fly_out_text(label_xy[0], label_xy[1], 'medium', conf_entry.conf_name,
                     'conferen label: ' + conf_entry.conf_name)

        #------------------------------------------------------------
        # bar and mark
        #------------------------------------------------------------
        # range bar: deadline pos, conference date pos
        dpos = get_bar_date_position(entry_orig_y, conf_entry.conf_deadline_date)
        cpos = get_bar_date_position(entry_orig_y, conf_entry.conf_end_date)
        fly_out_range_bar_triangle(dpos[0], dpos[1], cpos[0], cpos[1])

        # notification date if exists
        if !(conf_entry.conf_notification_date.nil?) then
          npos = get_bar_date_position(entry_orig_y, conf_entry.conf_notification_date)
          fly_out_circle(NOTIFICATIONMARK_COLOR, npos[0], npos[1], CIRCLE_SIZE)
        end

        #------------------------------------------------------------
        # date label
        #------------------------------------------------------------
        # range bar label (deadline)
        if $OPT_TEXTDEADLINE == '1' then
          dline_s = get_format_deadline_date(conf_entry)
          dpos = get_bar_date_position(entry_orig_y, conf_entry.conf_deadline_date)
          fly_out_text(dpos[0], dpos[1] - DATE_LABEL_HEIGHT - BAR_LABEL_T_MARGIN,
                       'small', dline_s, 'deadline: ' + dline_s)
        end

        # range bar label (conf date)
        if $OPT_TEXTCONFERENCE == '1' then
          conf_day_label = get_format_conf_date(conf_entry)
          cpos = get_bar_date_position(entry_orig_y, conf_entry.conf_end_date)
          fly_out_text(cpos[0], cpos[1] - DATE_LABEL_HEIGHT - BAR_LABEL_T_MARGIN,
                       'small', conf_day_label, 'conference date: ' + conf_day_label)
        end

        # notification date if exists
        if !(conf_entry.conf_notification_date.nil?) then
          if $OPT_TEXTNOTIFICATION == '1' then
            notf_text_y = npos[1] + BAR_LABEL_B_MARGIN
            notf_label  = get_format_notification_date(conf_entry)
            fly_out_text(npos[0], notf_text_y, 'small', notf_label,
                         'conference date: ' + notf_label)
          end
        end

        # for next label
        entry_orig_y = entry_orig_y + @grid_height
      end
    end
  end


  #
  # export fly file
  #
  def export_fly()
    begin
      assert(@grid_height != 0,
             'grid height is not initialized, init_canvas_size is not called?')
      fly_out_header()
      fly_out_entry_grid()
      fly_out_month_grid()
      fly_out_all_conf_entry()
    end
  end


  # export image map
  def export_image_map()
    begin
      assert(@grid_height != 0,
             'grid height is not initialized, init_canvas_size is not called?')

      x1s = 0.to_s
      x2s = @image_width.to_s

      @imagemapfile.print '<! image map file generated by draw_conf_schedule.rb -->' + "\n" +
        '<! ' + COPYRIGHT_STR + ' -->' + "\n" +
        '<! ' + VERSION_STR   + ' -->' + "\n"
      @imagemapfile.print '<map name="' + HTML_CONF_TABLE_MAP_NAME + '">' + "\n"

      entry_orig_y = TB_MARGIN + @grid_height
      for conf_entry in @conf_entry_array

        y1 = entry_orig_y
        y2 = entry_orig_y + @grid_height

        coords_s    = x1s + ',' + y1.to_s + ',' + x2s + ',' + y2.to_s
        confname    = conf_entry.conf_name + "_" * (MAX_CONF_NAME_LENGTH - conf_entry.conf_name.size)
        link_target = '#' + confname

        @imagemapfile.print '<area shape="rect" coords="' + coords_s + '" href="' +
          link_target + '" alt="' + confname + '">' + "\n"

        entry_orig_y =  entry_orig_y + @grid_height
      end

      @imagemapfile.print "</map>\n"
    end
  end


  #
  # read a file
  #
  # \param _infilename       input  data filename
  # \param _outfilename      output data filename
  # \param _imagemapfilename image map filename (html)
  #
  def read(_infilename, _outfilename, _imagemapfilename)
    begin
      # open the input
      if _infilename != "-" then
        @infilename = _infilename;
        # open the input
        @infile     = open(@infilename)
      end

      # open the output
      if _outfilename != "-" then
        @outfilename = _outfilename;
        # open the output file
        @outfile     = open(@outfilename, "w")
      end

      # open the image map out filename
      if _imagemapfilename != "-" then
        @imagemapfilename = _imagemapfilename;
        # open the output file
        @imagemapfile     = open(@imagemapfilename, "w")
      end

      # parse data file
      @current_n_line = 0
      parse_file()

      # sort by deadline
      sort_by_deadline()

      # initialize canvas
      init_canvas_size()

      # export fly file
      export_fly()

      # export image map
      export_image_map()

    rescue
      # `$!' has the last exception object
      print "Error! : " + $!.message  + "\n"
      print "--- Backtrace ---\n"
      $!.backtrace.each do |tracemes|
        print tracemes + "\n"
      end
    end
  end

  #----------------------------------------------------------------------
  # unit test
  #----------------------------------------------------------------------
  #
  # run the test
  #
  def run_test()
    begin

    rescue
      # `$!' has the last exception object
      print "Error! : " + $!.message  + "\n"
      print "--- Backtrace ---\n"
      $!.backtrace.each do |tracemes|
        print tracemes + "\n"
      end
    end
  end

end

#------------------------------
# command line option parsing
#------------------------------
args = GetoptLong.new();

args.set_options(['--infile',           '-i', GetoptLong::REQUIRED_ARGUMENT],
                 ['--outfile',          '-o', GetoptLong::REQUIRED_ARGUMENT],
                 ['--textdeadline',     '-d', GetoptLong::REQUIRED_ARGUMENT],
                 ['--textconference',   '-c', GetoptLong::REQUIRED_ARGUMENT],
                 ['--textnotification', '-n', GetoptLong::REQUIRED_ARGUMENT],
                 ['--month-name',       '-m', GetoptLong::REQUIRED_ARGUMENT],
                 ['--image-map-file',   '-I', GetoptLong::REQUIRED_ARGUMENT],
                 ['--help',             '-h', GetoptLong::NO_ARGUMENT],
                 ['--version',          '-V', GetoptLong::NO_ARGUMENT],
                 ['--verbose',          '-v', GetoptLong::NO_ARGUMENT]
                 );

begin
  args.each_option do |name, arg|
    # print(name + ", " + arg + ":\n")
    eval "$OPT_#{name.sub(/^--/, '').gsub(/-/, '_').upcase} = '#{arg}'"
  end
rescue
  exit(1)
end

#--- help
if $OPT_HELP
  print_help
  exit(1)
end

#--- show version
if $OPT_VERSION
  $stderr.print(DRAW_CONF_SCHEDULE_VERSION + "\n")
  exit(1)
end

#--- get infile
if !$OPT_INFILE
  $OPT_INFILE = "-"
end
if $OPT_VERBOSE
  print("OPT_INFILE  = " + $OPT_INFILE + "\n")
end

#--- get outfile
if !$OPT_OUTFILE
  $OPT_OUTFILE = "-"
end
if $OPT_VERBOSE
  print("OPT_OUTFILE = " + $OPT_OUTFILE + "\n")
end

#--- get image map file
if !$OPT_IMAGE_MAP_FILE
  $OPT_IMAGE_MAP_FILE = HTML_CONF_TABLE_MAP_DEFAULT_FILENAME
end
if $OPT_VERBOSE
  print("OPT_IMAGE_MAP_FILE = " + $OPT_IMAGE_MAP_FILE + "\n")
end

#--- get text switch
if !$OPT_TEXTDEADLINE
  # default: text deadline date on
  $OPT_TEXTDEADLINE = '1'
end
if !$OPT_TEXTCONFERENCE
  # default: text conference date on
  $OPT_TEXTCONFERENCE = '1'
end
if !$OPT_TEXTNOTIFICATION
  # default: text nootification date on
  $OPT_TEXTNOTIFICATION = '1'
end

#--- use month name
if !$OPT_MONTH_NAME
  # default: month name off
  $OPT_MONTH_NAME = '0'
end


if $OPT_VERBOSE
  print("OPT_TEXTDEADLINE     = " + $OPT_TEXTDEADLINE     + "\n")
  print("OPT_TEXTCONFERENCE   = " + $OPT_TEXTCONFERENCE   + "\n")
  print("OPT_TEXTNOTIFICATION = " + $OPT_TEXTNOTIFICATION + "\n")
  print("OPT_MONTH_NAME       = " + $OPT_MONTH_NAME       + "\n")
end

# --- expand
dcs = Draw_conf_schedule.new()

# dcs.run_test()

dcs.read($OPT_INFILE, $OPT_OUTFILE, $OPT_IMAGE_MAP_FILE)

# --- end of draw_conf_schedule.rb
