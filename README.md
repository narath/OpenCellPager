OpenCellPager
=============
OpenCellPager is a new paging system that utilizes cellphone SMS text messaging and a web browser. It is designed for use by hospitals and doctors in regions, such as Africa, where regular paging systems may not be available or are prohibitively expensive. There is already an impressive cellular phone infrastructure in Tanzania and many other parts of Africa, so this paging system could reach interns in the hospital and consultants at home without the need for any new expensive paging infrastructure. Since most doctors carry a cellphone, the technology infrastructure for a cellphone-based paging system already exists. OpenCellPager bridges the gap between this available infrastructure and the need for improved communications in healthcare settings.

For more, go to http://www.opencellpager.org

Installing
==========
1. Clone this repository into a local directory.
2. The default development server uses mysql, but you can change this to sqlite in database.yml
3. Copy database.yml.example to database.yml and edit
4. Copy local_settings.yml.example to local_settings.yml and edit to reflect your backend (Tropo has a free developer account and works well in North America with the system)
5. Copy mailer.yml.example to mailer.yml and edit to reflect your settings
6. Bundle install
7. bundle exec rake db:migrate
8. You should now be able to run the development server.

Dependencies
============
Rails 2.3.11
For Deploy: tested on Ubuntu, Nginx, Passenger, Mysql
Backends (any of): test, tropo, kannel (handles serial/usb modems), clickatell

Getting Help
============
Join the [discussion forum](http://groups.google.com/group/opencellpager)

Reporting Issues
================
Please post issues to the [issue tracking section](https://github.com/narath/OpenCellPager/issues)

License
=======
Copyright (c) 2011 Narath Carlile

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.



