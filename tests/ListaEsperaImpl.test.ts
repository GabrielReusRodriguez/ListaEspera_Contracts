/* eslint-disable no-undef */
// Right click on the script name and hit "Run" to execute
const { expect } = require("chai");
const { ethers } = require("hardhat");

async function expectRevert(promise, messageFragment) {
  try {
    await promise;
    expect.fail("Expected transaction to revert");
  } catch (error) {
    if (error.message === "Expected transaction to revert") throw error;
    expect(error.message).to.include(messageFragment);
  }
}

async function blockTimestamp() {
  const block = await ethers.provider.getBlock("latest");
  return block.timestamp;
}

async function deployImplStack(ownerSigner, adminSigner, aseguradoraSigner) {
  const ImplFactory = await ethers.getContractFactory("ListaEsperaImpl");
  const impl = await ImplFactory.deploy(
    ownerSigner.address,
    adminSigner.address
  );
  await impl.deployed();

  const StorageFactory = await ethers.getContractFactory("ListaEsperaStorage");
  const storage = await StorageFactory.deploy(impl.address, adminSigner.address);
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

  await (await impl.connect(adminSigner).setStorage(storage.address)).wait();
  await (
    await storage.connect(adminSigner).setGestorCentros(centros.address)
  ).wait();
  await (
    await storage
      .connect(adminSigner)
      .setGestorPruebasDiagnosticas(pruebas.address)
  ).wait();
  await (
    await storage
      .connect(adminSigner)
      .setGestorRedirecciones(redirecciones.address)
  ).wait();
  await (
    await storage
      .connect(adminSigner)
      .setAseguradora(aseguradoraSigner.address)
  ).wait();

  return { impl, storage, centros };
}

describe("ListaEsperaImpl", function () {
  let admin;
  let owner;
  let aseguradora;
  let centroA;
  let centroB;
  let other;
  let impl;
  let storage;

  beforeEach(async function () {
    [admin, owner, aseguradora, centroA, centroB, other] =
      await ethers.getSigners();
    ({ impl, storage } = await deployImplStack(owner, admin, aseguradora));
  });

  it("despliega e inicializa storage", async function () {
    console.log("ListaEsperaImpl deployed at:" + impl.address);
    expect(impl.address).to.be.a("string");
    expect(impl.address.length).to.equal(42);
  });

  it("solo el owner puede ejecutar la logica de negocio", async function () {
    await (
      await storage
        .connect(aseguradora)
        .creaCentro(centroA.address, "Centro A")
    ).wait();

    const ts = (await blockTimestamp()) - 60;
    await expectRevert(
      impl
        .connect(other)
        .alta(
          centroA.address,
          "CIP001",
          "RX",
          "Fractura",
          10,
          ts
        ),
      "Solo el owner puede ejeccutarlo"
    );
  });

  it("alta, consultas, redireccion y baja via owner", async function () {
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

    const ts = (await blockTimestamp()) - 120;
    await (
      await impl
        .connect(owner)
        .alta(centroA.address, "CIP001", "RX", "Fractura", 10, ts)
    ).wait();

    const porPaciente = await impl
      .connect(owner)
      .listaPruebasPorPaciente("CIP001");
    expect(porPaciente.length).to.equal(1);

    const porCentro = await impl
      .connect(owner)
      .listaPruebasPorCentro(centroA.address);
    expect(porCentro.length).to.equal(1);

    const prueba = await impl.connect(owner).obtenerPruebaPorId(1);
    expect(prueba.idPaciente).to.equal("CIP001");
    expect(prueba.diagnostico).to.equal("Fractura");

    await (
      await impl
        .connect(owner)
        .creaRedireccion(centroA.address, 1, centroB.address)
    ).wait();

    const pendientes = await impl
      .connect(owner)
      .listaRedireccionesPendientes(centroB.address);
    expect(pendientes.length).to.equal(1);

    await (
      await impl.connect(owner).aceptaRedireccion(centroB.address, 1)
    ).wait();

    const trasAceptar = await impl.connect(owner).obtenerPruebaPorId(1);
    expect(trasAceptar.centroRealizador).to.equal(centroB.address);

    const tsBaja = await blockTimestamp();
    await (
      await impl
        .connect(owner)
        .baja(centroB.address, 1, tsBaja, 3)
    ).wait();

    const baja = await impl.connect(owner).obtenerPruebaPorId(1);
    expect(baja.activa).to.equal(false);
    expect(baja.motivoDeBaja).to.equal(3);
  });

  it("rechaza redireccion via impl", async function () {
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
      await impl
        .connect(owner)
        .alta(centroA.address, "CIP001", "RX", "Fractura", 10, ts)
    ).wait();
    await (
      await impl
        .connect(owner)
        .creaRedireccion(centroA.address, 1, centroB.address)
    ).wait();
    await (
      await impl.connect(owner).rechazaRedireccion(centroB.address, 1)
    ).wait();

    const prueba = await impl.connect(owner).obtenerPruebaPorId(1);
    expect(prueba.centroRealizador).to.equal(centroA.address);
  });

  it("admin puede cambiar admin y storage", async function () {
    await expectRevert(
      impl.connect(other).setAdmin(other.address),
      "Solo lo pude gestionar el admin"
    );
    await (await impl.connect(admin).setAdmin(other.address)).wait();
    await (await impl.connect(other).setStorage(storage.address)).wait();
  });

  it("disable y enable propagan al storage", async function () {
    await (
      await storage
        .connect(aseguradora)
        .creaCentro(centroA.address, "Centro A")
    ).wait();

    await (await impl.connect(admin).disable()).wait();
    const ts = (await blockTimestamp()) - 60;
    await expectRevert(
      impl
        .connect(owner)
        .alta(centroA.address, "CIP001", "RX", "Fractura", 10, ts),
      "El contrato no esta activo"
    );

    await (await impl.connect(admin).enable()).wait();
    await (
      await impl
        .connect(owner)
        .alta(centroA.address, "CIP001", "RX", "Fractura", 10, ts)
    ).wait();
    const prueba = await impl.connect(owner).obtenerPruebaPorId(1);
    expect(prueba.activa).to.equal(true);
  });
});
