( function _Imap_test_ss_()
{

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

  test.case = 'read root directory';
  providers.effective.dirMake( '/hr' );
  var got = providers.effective.dirRead( '/' );
  var exp = [ 'Drafts', 'INBOX', 'Junk', 'Sent', 'Trash', 'hr' ];
  test.is( _.longHasAll( got, exp ) );

  /* */

  test.case = 'read subdirectory';
  providers.effective.dirMake( '/hr/1-new' );
  providers.effective.dirMake( '/hr/2-contacted' );
  providers.effective.fileWrite( '/hr/<$>', 'data' );
  var exp = [ '1-new', '2-contacted', '<1>' ];
  var got = providers.effective.dirRead( '/hr' );
  test.is( _.longHasAll( got, exp ) );

  /* */

  test.case = 'read nested directory';
  providers.effective.fileWrite( '/hr/1-new/<$>', 'data' );
  providers.effective.fileWrite( '/hr/1-new/<$>', 'data' );
  providers.effective.fileWrite( '/hr/1-new/<$>', 'data' );
  var got = providers.effective.dirRead( '/hr/1-new' );
  test.ge( got.length, 3 );

  /* */

  test.case = 'read not existed directory';
  var got = providers.effective.dirRead( '/doesNotExists' );
  var exp = null;
  test.identical( got, exp );

  test.case = 'read not existed nested directory';
  var got = providers.effective.dirRead( '/file/does/not/exist' );
  var exp = null;
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

  test.case = 'read existed file';
  providers.effective.fileWrite( '/hr/<$>', 'data' );
  var got = providers.effective.fileRead( '/hr/<1>' );
  var exp = [ 'attributes', 'parts', 'seqNo', 'header' ];
  test.identical( _.mapKeys( got ), exp );

  /* */

  test.case = 'read not existed file, throwing - 0';
  var got = providers.effective.fileRead({ filePath : '/hr/<999>', throwing : 0 });
  var exp = null;
  test.identical( got, exp );

  /* */

  test.case = 'read not existed directory, throwing - 0';
  var got = providers.effective.fileRead({ filePath : '/hrx', throwing : 0 });
  var exp = null;
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

  test.case = 'stat of existed file';
  providers.effective.fileWrite( '/hr/<$>', 'data' );
  var got = providers.effective.statRead( '/hr/<1>' );
  test.identical( got.isFile(), true );
  test.identical( got.isDir(), false );
  test.identical( got.isDirectory(), false );

  /* */

  test.case = 'stat of existed nested directory';
  providers.effective.dirMake( '/hr/1-new' );
  var got = providers.effective.statRead( '/hr/1-new' );
  test.identical( got.isFile(), false );
  test.identical( got.isDir(), true );
  test.identical( got.isDirectory(), true );

  /* */

  test.case = 'stat of not existed nested directory';
  var got = providers.effective.statRead({ filePath : '/hr/abc', throwing : 0 });
  test.identical( got, null );

  test.case = 'stat of not existed nested directory - 2 levels';
  var got = providers.effective.statRead({ filePath : '/hr/abc/abc', throwing : 0 });
  test.identical( got, null );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function fileExists( test )
{
  let context = this;
  let providers = context.providerMake();

  /* */

  test.case = 'check existed directory';
  var got = providers.effective.fileExists( '/INBOX' );
  test.identical( got, true );

  test.case = 'check not existed directory';
  var got = providers.effective.fileExists( '/notExistedDirectory' );
  test.identical( got, false );

  test.case = 'check not existed file';
  var got = providers.effective.fileExists( '/INBOX/<999>' );
  test.identical( got, false );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function fileWrite( test )
{
  let context = this;
  let providers = context.providerMake();

  /* */

  test.case = 'write file in existed directory';
  providers.effective.fileWrite( '/Drafts/<$>', 'data' );
  var got = providers.effective.dirRead( '/Drafts' );
  test.is( _.longHas( got, '<1>' ) );

  test.case = 'write file in not existed directory';
  providers.effective.fileWrite( '/user/<$>', 'data' );
  var got = providers.effective.dirRead( '/Drafts' );
  test.is( _.longHas( got, '<1>' ) );

  test.case = 'wrong name of file';
  test.shouldThrowErrorSync( () => providers.effective.fileWrite( '/INBOX/<2>', 'data' ) );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function fileDelete( test )
{
  let context = this;
  let providers = context.providerMake();

  if( providers.effective.fileExists( '/delete' ) )
  providers.effective.fileDelete( '/delete' );

  /* */

  test.case = 'delete single file';
  providers.effective.fileWrite( '/delete/<$>', 'data' );
  var got = providers.effective.dirRead( '/delete' );
  test.is( _.longHas( got, '<1>' ) );

  providers.effective.fileDelete( '/delete/<1>' );
  var got = providers.effective.dirRead( '/delete' );
  test.isNot( _.longHas( got, '<1>' ) );

  /* */

  test.case = 'delete single directory in root level';
  providers.effective.dirMake( '/delete' );
  var got = providers.effective.dirRead( '/delete' );
  test.identical( got, [] );

  providers.effective.fileDelete( '/delete' );
  var got = providers.effective.dirRead( '/' );
  test.isNot( _.longHas( got, 'delete' ) );

  /* */

  test.case = 'delete single directory in root level, directory with file';
  providers.effective.fileWrite( '/delete/<$>', 'data' );
  var got = providers.effective.dirRead( '/delete' );
  test.identical( got, [ '<1>' ] );

  providers.effective.fileDelete( '/delete' );
  var got = providers.effective.dirRead( '/' );
  test.isNot( _.longHas( got, 'delete' ) );

  /* */

  test.case = 'delete single nested directory';
  providers.effective.dirMake( '/delete/new' );
  var got = providers.effective.dirRead( '/delete' );
  test.identical( got, [ 'new' ] );

  providers.effective.fileDelete( '/delete/new' );
  var got = providers.effective.dirRead( '/delete' );
  test.identical( got, [] );

  /* */

  test.case = 'delete directory with nested directories';
  providers.effective.dirMake( '/delete/new/1/1' );
  providers.effective.dirMake( '/delete/new/2' );
  var got = providers.effective.dirRead( '/delete/new' );
  test.identical( got, [ '1', '2' ] );

  providers.effective.fileDelete( '/delete/new' );
  var got = providers.effective.dirRead( '/delete' );
  test.identical( got, [] );

  /* */

  test.case = 'delete directory with nested directories and files';
  providers.effective.fileWrite( '/delete/<$>', 'data' );
  providers.effective.fileWrite( '/delete/new/1/1/<$>', 'data' );
  providers.effective.fileWrite( '/delete/new/<$>', 'data' );
  providers.effective.dirMake( '/delete/new/2' );
  var got = providers.effective.dirRead( '/delete/new' );
  test.identical( got, [ '1', '2', '<1>' ] );

  providers.effective.fileDelete( '/delete' );
  var got = providers.effective.dirRead( '/' );
  test.isNot( _.longHas( got, 'delete' ) );

  /* */

  test.case = 'wrong name of file';
  test.shouldThrowErrorSync( () => providers.effective.fileDelete( '/INBOX/<999>' ) );

  test.case = 'wrong name of directory';
  test.shouldThrowErrorSync( () => providers.effective.fileDelete( '/unknown' ) );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function dirMake( test )
{
  let context = this;
  let providers = context.providerMake();

  /* */

  test.case = 'create new directory';
  providers.effective.dirMake( '/some' );
  var got = providers.effective.dirRead( '/' );
  test.is( _.longHas( got, 'some' ) );

  test.case = 'try to recreate existed directory';
  providers.effective.fileWrite( '/Drafts/<$>', 'data' );
  providers.effective.dirMake( '/Drafts' );
  var got = providers.effective.dirRead( '/Drafts' );
  test.is( _.longHas( got, '<1>' ) );

  test.case = 'create nested directory';
  providers.effective.dirMake( '/new/some' );
  var got = providers.effective.dirRead( '/' );
  test.is( _.longHas( got, 'new' ) );
  var got = providers.effective.dirRead( '/new' );
  test.identical( got, [ 'some' ] );

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
    fileExists,
    fileWrite,
    fileDelete,
    dirMake,

  },

}

//

let Self = new wTestSuite( Proto )
if( typeof module !== 'undefined' && !module.parent )
wTester.test( Self.name );

})();
