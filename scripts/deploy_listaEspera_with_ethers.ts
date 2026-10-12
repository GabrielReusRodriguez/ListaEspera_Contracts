// Deploy  de todos los contratos de ListaEspera usando ethers.js.
// Compila todos los contratos de "./contracts/" antes de ejecutar.
// Click derecho -> "Run"  para el menu contextual. Shortcut Ctrl+Shift+S 
//
// Orden:
// 1) ListaEspera(admin)
// 2) ListaEsperaImpl(listaEspera, admin) -> setImplementation
// 3) ListaEsperaStorage(impl, admin) -> setStorage
// 4) Storage children (owner = ListaEsperaStorage) -> setGestor*

import { ethers } from 'ethers'
import { deploy } from './ethers-lib'

(async () => {
  try {
    const signer = (new ethers.providers.Web3Provider(web3Provider)).getSigner()
    const admin = await signer.getAddress()
    console.log(`admin (deployer): ${admin}`)

    // 1. Proxy
    const listaEspera = await deploy('ListaEspera', [admin])
    console.log(`ListaEspera: ${listaEspera.address}`)

    // 2. Implementation (owner = ListaEspera)
    const listaEsperaImpl = await deploy('ListaEsperaImpl', [listaEspera.address, admin])
    console.log(`ListaEsperaImpl: ${listaEsperaImpl.address}`)

    let tx = await listaEspera.setImplementation(listaEsperaImpl.address)
    await tx.wait()
    console.log('ListaEspera.setImplementation OK')

    // 3. Main storage (owner = ListaEsperaImpl)
    const listaEsperaStorage = await deploy('ListaEsperaStorage', [listaEsperaImpl.address, admin])
    console.log(`ListaEsperaStorage: ${listaEsperaStorage.address}`)

    tx = await listaEsperaImpl.setStorage(listaEsperaStorage.address)
    await tx.wait()
    console.log('ListaEsperaImpl.setStorage OK')

    // 4. Storage children (owner = ListaEsperaStorage)
    const storageCentros = await deploy('ListaEsperaStorageCentros', [listaEsperaStorage.address])
    console.log(`ListaEsperaStorageCentros: ${storageCentros.address}`)

    const storagePruebas = await deploy('ListaEsperaStoragePruebasDiagnosticas', [listaEsperaStorage.address])
    console.log(`ListaEsperaStoragePruebasDiagnosticas: ${storagePruebas.address}`)

    const storageRedirecciones = await deploy('ListaEsperaStorageRedirecciones', [listaEsperaStorage.address])
    console.log(`ListaEsperaStorageRedirecciones: ${storageRedirecciones.address}`)

    tx = await listaEsperaStorage.setGestorCentros(storageCentros.address)
    await tx.wait()
    console.log('ListaEsperaStorage.setGestorCentros OK')

    tx = await listaEsperaStorage.setGestorPruebasDiagnosticas(storagePruebas.address)
    await tx.wait()
    console.log('ListaEsperaStorage.setGestorPruebasDiagnosticas OK')

    tx = await listaEsperaStorage.setGestorRedirecciones(storageRedirecciones.address)
    await tx.wait()
    console.log('ListaEsperaStorage.setGestorRedirecciones OK')

    console.log('--- deploy complete ---')
    console.log(`ListaEspera: ${listaEspera.address}`)
    console.log(`ListaEsperaImpl: ${listaEsperaImpl.address}`)
    console.log(`ListaEsperaStorage: ${listaEsperaStorage.address}`)
    console.log(`ListaEsperaStorageCentros: ${storageCentros.address}`)
    console.log(`ListaEsperaStoragePruebasDiagnosticas: ${storagePruebas.address}`)
    console.log(`ListaEsperaStorageRedirecciones: ${storageRedirecciones.address}`)
  } catch (e) {
    console.log(e.message)
  }
})()
