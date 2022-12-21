<script>
    import WalletConnect from "../lib/WalletConnect.svelte";
    import contractAbi from "../contracts/ETHPoolHandler.json";
    const contractAddr =  "0x3E8FD4A8ce96F09CCEc51a8ED4240D966EccEA57";
    export let web3Props = {
        provider : null,
        signer : null,
        account : null,
        chainId : null
    };

</script>

<div class="OUTER">
<WalletConnect bind:web3Props {contractAddr} {contractAbi} />
</div>

<style>
    .OUTER {
        border-radius: 15px;
        padding: 20px;
        overflow: hidden;
        position: relative;
        background-color: rgb(231, 146, 20);
        box-shadow: 1px 4px 1px rgba(0,0,0,0.3);
    }
</style>