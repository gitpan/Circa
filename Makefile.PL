use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Circa',
    'VERSION_FROM' => 'lib/Circa.pm', # finds $VERSION
    'PREREQ_PM'    => 
	      { 
	       'DBI'           => 0, 
	       'DBD::mysql'    => 0 ,
	       'URI::URL'      => 0 ,
	       'LWP::RobotUA'  => 0,
	      },
    'dist'=>
       {TARFLAGS => 'cvf', 
	COMPRESS => 'gzip', 
	SUFFIX => 'gz', 
	DIST_CP => 'ln',
	DIST_DEFAULT => 'all tardist'}    
);
