pragma solidity 0.4.24;

import "@aragon/templates-shared/contracts/TokenCache.sol";
import "@aragon/templates-shared/contracts/BaseTemplate.sol";

import "@aragon/token-wrapper/contracts/TokenWrapper.sol";


contract DecentralandTemplate is BaseTemplate, TokenCache {
    bytes32 constant internal TOKEN_WRAPPER_APP_ID = 0x84fda9a3c8655fa3cc349a8375729741fc6f4cacca230ed8bfb04b38e833a961;

    string constant private ERROR_BAD_VOTE_SETTINGS = "DECENTRALAND_BAD_VOTE_SETTINGS";
    string constant private ERROR_BAD_MANA_TOKEN = "DECENTRALAND_BAD_MANA_TOKEN";
    string constant private ERROR_BAD_MULTISIG = "DECENTRALAND_BAD_MULTISIG";

    bool constant private TOKEN_TRANSFERABLE = false;
    uint8 constant private TOKEN_DECIMALS = uint8(18);
    uint256 constant private TOKEN_MAX_PER_ACCOUNT = uint256(0);

    constructor(DAOFactory _daoFactory, ENS _ens, MiniMeTokenFactory _miniMeFactory, IFIFSResolvingRegistrar _aragonID)
        BaseTemplate(_daoFactory, _ens, _miniMeFactory, _aragonID)
        public
    {
        _ensureAragonIdIsValid(_aragonID);
        _ensureMiniMeFactoryIsValid(_miniMeFactory);
    }

    function newToken(string memory _name, string memory _symbol) public returns (MiniMeToken) {
        MiniMeToken token = _createToken(_name, _symbol, TOKEN_DECIMALS);
        _cacheToken(token, msg.sender);
        return token;
    }

    function newInstance(string memory _id, ERC20 _mana, address _dclMultiSig, uint64[3] memory _votingSettings) public {
        _validateId(_id);
        _validateVotingSettings(_votingSettings);
        _validateManaToken(_mana);
        _validateMultiSig(_dclMultiSig);

        (Kernel dao, ACL acl) = _createDAO();
        Voting voting = _setupApps(dao, acl, _mana, _dclMultiSig, _votingSettings);

        _transferRootPermissionsFromTemplateAndFinalizeDAO(dao, _dclMultiSig);
        _registerID(_id, dao);
    }

    function _setupApps(Kernel _dao, ACL _acl, ERC20 _mana, address _dclMultiSig, uint64[3] memory _votingSettings) internal returns (Voting) {
        MiniMeToken token = _popTokenCache(msg.sender);
        Agent agent = _installDefaultAgentApp(_dao);
        Voting voting = _installVotingApp(_dao, token, _votingSettings);
        TokenWrapper tokenWrapper = _installTokenWrapperApp(_dao, token, _mana);

        _setupPermissions(_acl, agent, voting, tokenWrapper, _dclMultiSig);

        return voting;
    }

    function _installTokenWrapperApp(Kernel _dao, MiniMeToken _token, ERC20 _mana) internal returns (TokenWrapper) {
        TokenWrapper tokenWrapper = TokenWrapper(_installNonDefaultApp(_dao, TOKEN_WRAPPER_APP_ID));
        _token.changeController(tokenWrapper);
        tokenWrapper.initialize(_token, _mana);
        return tokenWrapper;
    }

    function _setupPermissions(ACL _acl, Agent _agent, Voting _voting, TokenWrapper _tokenWrapper, address _dclMultiSig) internal {
        _createCustomAgentPermissions(_acl, _agent, _voting, _dclMultiSig);
        _createEvmScriptsRegistryPermissions(_acl, _voting, _voting);
        _createVotingPermissions(_acl, _voting, _voting, _tokenWrapper, _dclMultiSig);
    }

    function _createCustomAgentPermissions(ACL _acl, Agent _agent, Voting _voting, address _dclMultiSig) internal {
        _acl.createPermission(_voting, _agent, _agent.EXECUTE_ROLE(), address(this));
        _acl.createPermission(_voting, _agent, _agent.RUN_SCRIPT_ROLE(), address(this));

        _acl.grantPermission(_dclMultiSig, _agent, _agent.EXECUTE_ROLE());
        _acl.grantPermission(_dclMultiSig, _agent, _agent.RUN_SCRIPT_ROLE());

        _acl.setPermissionManager(_dclMultiSig, _agent, _agent.EXECUTE_ROLE());
        _acl.setPermissionManager(_dclMultiSig, _agent, _agent.RUN_SCRIPT_ROLE());
    }

    function _validateMultiSig(address _multiSig) internal {
        require(isContract(_multiSig), ERROR_BAD_MULTISIG);
    }

    function _validateManaToken(ERC20 _mana) internal {
        require(isContract(_mana), ERROR_BAD_MANA_TOKEN);
    }

    function _validateVotingSettings(uint64[3] memory _votingSettings) internal {
        require(_votingSettings.length == 3, ERROR_BAD_VOTE_SETTINGS);
    }
}
