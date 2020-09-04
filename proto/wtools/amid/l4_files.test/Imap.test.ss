( function _Imap_test_ss_( ) {

'use strict';

if( typeof module !== 'undefined' )
{
  let _ = require( '../../../wtools/Tools.s' );

  _.include( 'wTesting' );
  _.include( 'wResolver' );
  _.include( 'wCensorBasic' );

  require( '../l4_files/entry/Imap.ss' );
}

let _ = _global_.wTools;

// --
// context
// --

function onSuiteBegin( test )
{
  let context = this;
  context.suiteTempPath = _.fileProvider.path.tempOpen( _.fileProvider.path.join( __dirname, '../..'  ), 'FileProviderImap' );
}

//

function onSuiteEnd( test )
{
  let context = this;
  _.fileProvider.path.tempClose( context.suiteTempPath );
}

//

function providerMake()
{
  let context = this;

  let config = _.censor.configRead();
  let cred = _.resolver.resolve({ selector : context.cred, src : config });

  let providers = Object.create( null );
  providers.effective = providers.imap = _.FileProvider.Imap( cred );
  providers.hd = _.FileProvider.HardDrive();
  providers.extract = _.FileProvider.Extract({ protocols : [ 'extract' ] });
  providers.system = _.FileProvider.System({ providers : [ providers.effective, providers.hd, providers.extract ] });

  // let provider = _.FileProvider.Extract({ protocols : [ 'current', 'second' ] });
  // let system = _.FileProvider.System({ providers : [ provider ] }); /* xxx : try without the system ? */
  // _.assert( system.defaultProvider === null );

  return providers;
}

// --
// tests
// --

function login( test )
{
  let context = this;
  let providers = context.providerMake();
  providers.effective.ready.then( () => providers.effective.unform() );
  providers.effective.ready.then( () => test.is( true ) );
  return providers.effective.ready;
}

//

function dirRead( test )
{
  let context = this;
  let providers = context.providerMake();

  /* */

  var exp = [ 'Drafts', 'hr', 'INBOX', 'Junk', 'reports', 'Sent', 'system', 'Templates', 'Trash' ];
  var got = providers.effective.dirRead( '/' );
  test.identical( got, exp );

  /* */

  var exp = [ '1-new', '2-contacted', '2-men', '3-video', '5-interesting', '9-no', '<1>' ];
  var got = providers.effective.dirRead( '/hr' );
  test.identical( got, exp );

  /* */

  var got = providers.effective.dirRead( '/hr/1-new' );
  logger.log( got );
  test.ge( got.length, 3 );

  /* */

  var exp = null;
  var got = providers.effective.dirRead( '/doesNotExists' );
  test.identical( got, exp );

  var exp = null;
  var got = providers.effective.dirRead( '/file/does/not/exist' );
  test.identical( got, exp );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function fileRead( test )
{
  let context = this;
  let providers = context.providerMake();

  /* */

  var exp = [ 'attributes', 'parts', 'seqNo', 'header' ];
  var got = providers.effective.fileRead( '/hr/<1>' );
  test.identical( _.mapKeys( got ), exp );

  /* */

  var exp = null;
  var got = providers.effective.fileRead({ filePath : '/hr/<999>', throwing : 0 });
  test.identical( got, exp );

  /* */

  var exp = null;
  var got = providers.effective.fileRead({ filePath : '/hrx', throwing : 0 });
  test.identical( got, exp );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function statRead( test )
{
  let context = this;
  let providers = context.providerMake();

  /* */

  var got = providers.effective.statRead( '/hr/<1>' );
  test.identical( got.isFile(), true );
  test.identical( got.isDir(), false );
  test.identical( got.isDirectory(), false );

  /* */

  var got = providers.effective.statRead( '/hr/1-new' );
  test.identical( got.isFile(), false );
  test.identical( got.isDir(), true );
  test.identical( got.isDirectory(), true );

  /* */

  var got = providers.effective.statRead({ filePath : '/hr/abc', throwing : 0 });
  test.identical( got, null );

  /* */

  var got = providers.effective.statRead({ filePath : '/hr/abc/abc', throwing : 0 });
  test.identical( got, null );

  /* */

  var got = providers.effective.statRead({ filePath : '/hr/<999>', throwing : 0 });
  test.identical( got, null );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

// --
// declare
// --

var Proto =
{

  name : 'Tools.mid.files.fileProvider.Imap',
  silencing : 1,
  enabled : 1,
  routineTimeOut : 60000,

  onSuiteBegin,
  onSuiteEnd,

  context :
  {
    providerMake,
    suiteTempPath : null,
    cred :
    {
      login : 'about/email.login',
      password : 'about/email.password',
      hostUri : 'about/email.imap',
      tls : 'about/email.tls',
    }
  },

  tests :
  {

    login,
    dirRead,
    fileRead,
    statRead,

  },

}

//

let Self = new wTestSuite( Proto )
if( typeof module !== 'undefined' && !module.parent )
wTester.test( Self.name );

})();
