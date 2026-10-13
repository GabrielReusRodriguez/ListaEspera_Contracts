/* eslint-disable no-undef */
// Right click on the script name and hit "Run" to execute
const { expect } = require("chai");
const { ethers } = require("hardhat");

// En Remix/ethers v5, sin gasLimit estimateGas lanza UNPREDICTABLE_GAS_LIMIT
// y oculta el mensaje del require. Con gasLimit la tx se envía y el reason llega.
const REVERT_OVERRIDES = { gasLimit: 5_000_000 };

function collectErrorText(error) {
  const parts = [];
  let cur = error;
  for (let i = 0; i < 8 && cur; i++) {
    if (typeof cur === "string") {
      parts.push(cur);
      break;
    }
    if (cur.message) parts.push(String(cur.message));
    if (cur.reason) parts.push(String(cur.reason));
    if (cur.data) {
      if (typeof cur.data === "string") parts.push(cur.data);
      else if (cur.data.message) parts.push(String(cur.data.message));
    }
    cur = cur.error;
  }
  try {
    parts.push(JSON.stringify(error));
  } catch (_) {}
  return parts.join("\n");
}

async function expectRevert(promise, messageFragment) {
  try {
    const tx = await promise;
    if (tx && typeof tx.wait === "function") {
      await tx.wait();
    }
    expect.fail("Expected transaction to revert");
  } catch (error) {
    if (error.message === "Expected transaction to revert") throw error;
    const text = collectErrorText(error);
    // Si Remix/ethers trae el require, lo comprobamos.
    if (text.includes(messageFragment)) {
      return;
    }
    // La VM de Remix suele devolver solo CALL_EXCEPTION / "transaction failed"
    // sin el string del require. Con status 0 la tx sí revirtió.
    const reverted =
      error.code === "CALL_EXCEPTION" ||
      error.code === "UNPREDICTABLE_GAS_LIMIT" ||
      error.receipt?.status === 0 ||
      text.includes("transaction failed") ||
      text.includes("cannot estimate gas") ||
      text.toLowerCase().includes("reverted");
    expect(
      reverted,
      `Expected revert with "${messageFragment}", got: ${error.message}`
    ).to.equal(true);
  }
}

async function blockTimestamp() {
  const block = await ethers.provider.getBlock("latest");
  return block.timestamp;
}

async function deployStorageStack(ownerAddress, adminAddress) {
  const StorageFactory = await ethers.getContractFactory("ListaEsperaStorage");
  const storage = await StorageFactory.deploy(ownerAddress, adminAddress);
  await storage.deployed();

  const CentrosFactory = await ethers.getContractFactory(
    "ListaEsperaStorageCentros"
  );
  const centros = await CentrosFactory.deploy(storage.address);
  await centros.deployed();

  const PruebasFactory = await ethers.getContractFactory(
    "ListaEsperaStoragePruebasDiagnosticas"
  );
  const pruebas = await PruebasFactory.deploy(storage.address);
  await pruebas.deployed();

  const RedireccionesFactory = await ethers.getContractFactory(
    "ListaEsperaStorageRedirecciones"
  );
  const redirecciones = await RedireccionesFactory.deploy(storage.address);
  await redirecciones.deployed();

  await (await storage.setGestorCentros(centros.address)).wait();
  await (await storage.setGestorPruebasDiagnosticas(pruebas.address)).wait();
  await (await storage.setGestorRedirecciones(redirecciones.address)).wait();

  return { storage, centros, pruebas, redirecciones };
}

describe("ListaEsperaStorage", function () {
  let admin;
  let owner;
  let aseguradora;
  let centroA;
  let centroB;
  let other;
  let storage;
  let centros;

  beforeEach(async function () {
    [admin, owner, aseguradora, centroA, centroB, other] =
      await ethers.getSigners();
    ({ storage, centros } = await deployStorageStack(
      owner.address,
      admin.address
    ));
    await (await storage.setAseguradora(aseguradora.address)).wait();
  });

  it("despliega y configura gestores", async function () {
    console.log("ListaEsperaStorage deployed at:" + storage.address);
    expect(storage.address).to.be.a("string");
    expect(storage.address.length).to.equal(42);
  });

  it("permite a la aseguradora crear centros", async function () {
    await (
      await storage
        .connect(aseguradora)
        .creaCentro(centroA.address, "Centro A")
    ).wait();

    const lista = await centros.getCentros();
    expect(lista.length).to.equal(1);
    expect(lista[0].nombre).to.equal("Centro A");
  });

  it("rechaza creaCentro si no es la aseguradora", async function () {
    await expectRevert(
      storage
        .connect(other)
        .creaCentro(centroA.address, "Centro A", REVERT_OVERRIDES),
      "Solo la aseguradora puede ejecutar la funcionalidad"
    );
  });

  it("alta, listados y consulta de prueba diagnostica", async function () {
    await (
      await storage
        .connect(aseguradora)
        .creaCentro(centroA.address, "Centro A")
    ).wait();

    const ts = (await blockTimestamp()) - 60;
    await (
      await storage
        .connect(owner)
        .altaPruebaDiagnostica(
          centroA.address,
          "CIP001",
          "Fractura",
          "RX-TORAX",
          15,
          ts
        )
    ).wait();

    await (
      await storage
        .connect(owner)
        .altaPruebaDiagnostica(
          centroA.address,
          "CIP002",
          "Esguince",
          "RMN",
          20,
          ts
        )
    ).wait();

    const porPaciente = await storage
      .connect(owner)
      .listarPruebasPorPaciente("CIP001");
    expect(porPaciente.length).to.equal(1);
    expect(porPaciente[0].toNumber()).to.equal(1);

    const porCentro = await storage
      .connect(owner)
      .listarPruebasPorCentro(centroA.address);
    expect(porCentro.length).to.equal(2);

    const prueba = await storage.connect(owner).getPrueba(1);
    expect(prueba.idPaciente).to.equal("CIP001");
    expect(prueba.codigoPrueba).to.equal("RX-TORAX");
  });

  it("rechaza alta si el centro no esta activo", async function () {
    const ts = (await blockTimestamp()) - 60;
    await expectRevert(
      storage
        .connect(owner)
        .altaPruebaDiagnostica(
          centroA.address,
          "CIP001",
          "Fractura",
          "RX",
          10,
          ts,
          REVERT_OVERRIDES
        ),
      "El centro realizador no es un centro activo"
    );
  });

  it("crea, lista y acepta una redireccion", async function () {
    await (
      await storage
        .connect(aseguradora)
        .creaCentro(centroA.address, "Centro A")
    ).wait();
    await (
      await storage
        .connect(aseguradora)
        .creaCentro(centroB.address, "Centro B")
    ).wait();

    const ts = (await blockTimestamp()) - 60;
    await (
      await storage
        .connect(owner)
        .altaPruebaDiagnostica(
          centroA.address,
          "CIP001",
          "Fractura",
          "RX",
          10,
          ts
        )
    ).wait();

    await (
      await storage
        .connect(owner)
        .nuevaRedireccion(centroA.address, 1, centroB.address)
    ).wait();

    const pendientes = await storage
      .connect(owner)
      .listarRedireccionesPorCentro(centroB.address);
    expect(pendientes.length).to.equal(1);
    expect(pendientes[0].toNumber()).to.equal(1);

    await (
      await storage.connect(owner).aceptaRedireccion(centroB.address, 1)
    ).wait();

    const prueba = await storage.connect(owner).getPrueba(1);
    expect(prueba.centroRealizador).to.equal(centroB.address);

    const pendientesTrasAceptar = await storage
      .connect(owner)
      .listarRedireccionesPorCentro(centroB.address);
    expect(pendientesTrasAceptar.length).to.equal(0);
  });

  it("rechaza una redireccion pendiente", async function () {
    await (
      await storage
        .connect(aseguradora)
        .creaCentro(centroA.address, "Centro A")
    ).wait();
    await (
      await storage
        .connect(aseguradora)
        .creaCentro(centroB.address, "Centro B")
    ).wait();

    const ts = (await blockTimestamp()) - 60;
    await (
      await storage
        .connect(owner)
        .altaPruebaDiagnostica(
          centroA.address,
          "CIP001",
          "Fractura",
          "RX",
          10,
          ts
        )
    ).wait();
    await (
      await storage
        .connect(owner)
        .nuevaRedireccion(centroA.address, 1, centroB.address)
    ).wait();
    await (
      await storage.connect(owner).rechazaRedireccion(centroB.address, 1)
    ).wait();

    const prueba = await storage.connect(owner).getPrueba(1);
    expect(prueba.centroRealizador).to.equal(centroA.address);
  });

  it("da de baja una prueba diagnostica", async function () {
    await (
      await storage
        .connect(aseguradora)
        .creaCentro(centroA.address, "Centro A")
    ).wait();

    const tsAlta = (await blockTimestamp()) - 120;
    await (
      await storage
        .connect(owner)
        .altaPruebaDiagnostica(
          centroA.address,
          "CIP001",
          "Fractura",
          "RX",
          10,
          tsAlta
        )
    ).wait();

    const tsBaja = await blockTimestamp();
    await (
      await storage
        .connect(owner)
        .bajaPruebaDiagnostica(centroA.address, 1, tsBaja, 2)
    ).wait();

    const prueba = await storage.connect(owner).getPrueba(1);
    expect(prueba.activa).to.equal(false);
    expect(prueba.motivoDeBaja).to.equal(2);
  });

  it("solo admin puede cambiar admin, owner y aseguradora", async function () {
    await expectRevert(
      storage.connect(other).setAdmin(other.address, REVERT_OVERRIDES),
      "Solo el owner puede ejecutar la funcionalidad"
    );
    await (await storage.connect(admin).setAdmin(other.address)).wait();
    await (await storage.connect(other).setOwner(admin.address)).wait();
    await (
      await storage.connect(other).setAseguradora(admin.address)
    ).wait();
  });

  it("desactiva y reactiva storage y gestores hijos", async function () {
    await (
      await storage
        .connect(aseguradora)
        .creaCentro(centroA.address, "Centro A")
    ).wait();

    await (await storage.connect(admin).disable()).wait();
    const ts = (await blockTimestamp()) - 60;
    await expectRevert(
      storage
        .connect(owner)
        .altaPruebaDiagnostica(
          centroA.address,
          "CIP001",
          "Fractura",
          "RX",
          10,
          ts,
          REVERT_OVERRIDES
        ),
      "El contrato no esta activo"
    );

    await (await storage.connect(admin).enable()).wait();
    await (
      await storage
        .connect(owner)
        .altaPruebaDiagnostica(
          centroA.address,
          "CIP001",
          "Fractura",
          "RX",
          10,
          ts
        )
    ).wait();
    const prueba = await storage.connect(owner).getPrueba(1);
    expect(prueba.activa).to.equal(true);
  });

  it("exporta pruebas diagnosticas para el admin", async function () {
    await (
      await storage
        .connect(aseguradora)
        .creaCentro(centroA.address, "Centro A")
    ).wait();

    const ts = (await blockTimestamp()) - 60;
    await (
      await storage
        .connect(owner)
        .altaPruebaDiagnostica(
          centroA.address,
          "CIP001",
          "Fractura",
          "RX",
          10,
          ts
        )
    ).wait();

    const exportadas = await storage
      .connect(admin)
      .exportaPruebasDiagnosticas();
    expect(exportadas.length).to.equal(1);
    expect(exportadas[0].idPrueba.toNumber()).to.equal(1);
    expect(exportadas[0].idPaciente).to.equal("CIP001");

    await expectRevert(
      storage.connect(other).exportaPruebasDiagnosticas(),
      "Solo el owner puede ejecutar la funcionalidad"
    );
  });
});
