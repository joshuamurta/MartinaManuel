(() => {
  const { cabins, reviews, whatsapp, firebaseProjectId } = window.SITE;
  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
  const arrow = '<svg viewBox="0 0 24 24"><path d="M5 12h13m-5-6 6 6-6 6"/></svg>';

  $('[data-year]').textContent = new Date().getFullYear();

  /* ---------- Header compacto al hacer scroll ---------- */
  const header = $('[data-header]');
  const onScroll = () => header.classList.toggle('is-scrolled', window.scrollY > 120);
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  /* ---------- Menú ---------- */
  const menu = $('[data-menu]');
  const menuBtn = $('[data-menu-open]');
  const openMenu = () => { menu.hidden = false; menuBtn.setAttribute('aria-expanded', 'true'); $('a', menu).focus(); };
  const closeMenu = () => { menu.hidden = true; menuBtn.setAttribute('aria-expanded', 'false'); menuBtn.focus(); };
  menuBtn.addEventListener('click', openMenu);
  $('[data-menu-close]').addEventListener('click', closeMenu);
  menu.addEventListener('click', e => { if (e.target === menu || e.target.closest('a')) closeMenu(); });
  document.addEventListener('keydown', e => { if (e.key === 'Escape' && !menu.hidden) closeMenu(); });

  /* ---------- Cabañas ---------- */
  const photosOf = c => [`img/cabana-${c.id}.webp`, ...Array.from({ length: c.photos }, (_, i) => `img/galeria/c${c.id}-${String(i + 1).padStart(2, '0')}.webp`)];

  $('[data-cabins]').innerHTML = cabins.map(c => `
    <li class="cabin-card reveal">
      <button type="button" data-cabin="${c.id}" aria-label="Ver ${c.name}, ${c.capacity}, ${c.size} metros cuadrados">
        <div class="cabin-photo">
          <img src="img/cabana-${c.id}.webp" alt="" loading="lazy">
          <span class="sticker">${c.tag}</span>
          <span class="cabin-num" aria-hidden="true">${c.id}</span>
        </div>
        <div class="cabin-info">
          <h3>${c.name}</h3>
          <div class="cabin-meta"><span class="chip">${c.capacity}</span><span class="chip">${c.size} m²</span></div>
          <p>${c.blurb}</p>
          <span class="cabin-more">Ver cabaña ${arrow}</span>
        </div>
      </button>
    </li>`).join('');

  const cabinSelect = $('[data-cabin-select]');
  cabins.forEach(c => cabinSelect.insertAdjacentHTML('beforeend', `<option value="${c.id}">${c.name} · ${c.capacity}</option>`));

  /* ---------- Diálogo de cabaña ---------- */
  const dlg = $('[data-dialog]');
  const dlgImg = $('[data-dlg-img]');
  let gallery = [], gIndex = 0, current = null;

  const showPhoto = i => {
    gIndex = (i + gallery.length) % gallery.length;
    dlgImg.src = gallery[gIndex];
    dlgImg.alt = `${current.name}, foto ${gIndex + 1} de ${gallery.length}`;
    $('[data-dlg-count]').textContent = `${gIndex + 1}/${gallery.length}`;
    new Image().src = gallery[(gIndex + 1) % gallery.length]; // precarga la siguiente
  };

  const openCabin = id => {
    current = cabins.find(c => c.id === id);
    gallery = photosOf(current);
    $('[data-dlg-tag]').textContent = current.tag;
    $('[data-dlg-title]').textContent = current.name;
    $('[data-dlg-meta]').textContent = `Capacidad ${current.capacity} · ${current.size} m²`;
    $('[data-dlg-features]').innerHTML = current.features.map(f => `<li>${f}</li>`).join('');
    showPhoto(0);
    dlg.showModal();
  };

  $('[data-cabins]').addEventListener('click', e => {
    const btn = e.target.closest('[data-cabin]');
    if (btn) openCabin(Number(btn.dataset.cabin));
  });
  $('[data-dlg-prev]').addEventListener('click', () => showPhoto(gIndex - 1));
  $('[data-dlg-next]').addEventListener('click', () => showPhoto(gIndex + 1));
  $('[data-dialog-close]').addEventListener('click', () => dlg.close());
  dlg.addEventListener('click', e => { if (e.target === dlg) dlg.close(); });
  dlg.addEventListener('keydown', e => {
    if (e.key === 'ArrowRight') showPhoto(gIndex + 1);
    if (e.key === 'ArrowLeft') showPhoto(gIndex - 1);
  });
  $('[data-dlg-book]').addEventListener('click', e => {
    // Al cerrar, el diálogo devuelve el foco a la tarjeta y cancela el salto al ancla
    e.preventDefault();
    cabinSelect.value = String(current.id);
    dlg.close();
    requestAnimationFrame(() => $('#reservar').scrollIntoView({ behavior: 'smooth' }));
  });

  /* ---------- Opiniones ---------- */
  const track = $('[data-track]');
  const initials = n => n.split(' ').map(w => w[0]).slice(0, 2).join('');
  track.innerHTML = reviews.map(r => `
    <li class="review">
      <blockquote>“${r.text}”</blockquote>
      <footer><cite>${r.name}</cite><span class="badge" aria-hidden="true">${initials(r.name)}</span></footer>
    </li>`).join('');
  $('[data-total]').textContent = reviews.length;

  let rIndex = 0;
  const slideTo = i => {
    rIndex = Math.max(0, Math.min(reviews.length - 1, i));
    const card = track.children[rIndex];
    track.style.transform = `translateX(${-card.offsetLeft}px)`;
    $('[data-current]').textContent = rIndex + 1;
  };
  $('[data-prev]').addEventListener('click', () => slideTo(rIndex - 1));
  $('[data-next]').addEventListener('click', () => slideTo(rIndex + 1 >= reviews.length ? 0 : rIndex + 1));
  window.addEventListener('resize', () => slideTo(rIndex));

  // Deslizar con el dedo
  let touchX = null;
  track.addEventListener('touchstart', e => { touchX = e.touches[0].clientX; }, { passive: true });
  track.addEventListener('touchend', e => {
    if (touchX === null) return;
    const dx = e.changedTouches[0].clientX - touchX;
    if (Math.abs(dx) > 40) slideTo(rIndex + (dx < 0 ? 1 : -1));
    touchX = null;
  });

  /* ---------- Reserva ---------- */
  const MONTHS = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  const DOW = ['LU', 'MA', 'MI', 'JU', 'VI', 'SA', 'DO'];
  const today = new Date(); today.setHours(0, 0, 0, 0);
  const firstMonth = new Date(today.getFullYear(), today.getMonth(), 1);
  let viewMonth = new Date(firstMonth);
  let checkIn = null, checkOut = null;

  const calEl = $('[data-cal]');
  const nextBtn = $('[data-go="2"]', $('[data-step="1"]'));
  const fmt = d => `${d.getDate()} de ${MONTHS[d.getMonth()]}`;
  const fmtLong = d => d.toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
  const nights = () => Math.round((checkOut - checkIn) / 864e5);

  /* ---------- Disponibilidad (la publica la app de gestión) ---------- */
  // cabaña → rangos [llegada, salida) en 'aaaa-mm-dd'; la noche de salida queda libre.
  let busy = null;
  const key = d => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  const nightTaken = (id, k) => (busy[id] || []).some(([a, b]) => a <= k && k < b);
  const freeOn = d => busy ? cabins.filter(c => !nightTaken(c.id, key(d))) : cabins;
  const freeBetween = (a, b) => {
    if (!busy) return cabins;
    const ka = key(a), kb = key(b);
    return cabins.filter(c => !(busy[c.id] || []).some(([x, y]) => x < kb && y > ka));
  };

  const loadAvailability = async () => {
    if (!firebaseProjectId) return;
    try {
      const url = `https://firestore.googleapis.com/v1/projects/${firebaseProjectId}/databases/(default)/documents/public/availability`;
      const doc = await (await fetch(url)).json();
      busy = JSON.parse(doc.fields.json.stringValue).cabins;
      calEl.classList.add('has-availability');
      renderCal();
    } catch (err) {
      busy = null; // sin datos el calendario sigue funcionando como consulta
    }
  };

  const renderMonth = base => {
    const y = base.getFullYear(), m = base.getMonth();
    const offset = (new Date(y, m, 1).getDay() + 6) % 7; // semana empieza en lunes
    const days = new Date(y, m + 1, 0).getDate();
    let html = `<div class="cal-month"><h4>${MONTHS[m]} ${y}</h4><div class="cal-grid">`;
    html += DOW.map(d => `<span class="cal-dow">${d}</span>`).join('');
    html += '<span></span>'.repeat(offset);
    const pickingOut = checkIn && !checkOut;
    for (let d = 1; d <= days; d++) {
      const date = new Date(y, m, d);
      const t = date.getTime();
      const cls = ['cal-day'];
      const free = freeOn(date).length;
      // Eligiendo la salida vale cualquier día hasta donde quede una cabaña libre todo el rango.
      const canOut = pickingOut && date > checkIn && freeBetween(checkIn, date).length > 0;
      const disabled = date < today || (busy && !canOut && free === 0);
      if (t === today.getTime()) cls.push('is-today');
      if (checkIn && t === checkIn.getTime()) cls.push('is-start');
      if (checkOut && t === checkOut.getTime()) cls.push('is-end');
      if (checkIn && checkOut && t > checkIn && t < checkOut) cls.push('in-range');
      if (busy && date >= today && free === 0) cls.push('is-full');
      else if (busy && date >= today && free <= 2) cls.push('is-few');
      const status = !busy || date < today ? '' : free === 0 ? ', sin cabañas libres' : `, ${free} ${free === 1 ? 'cabaña libre' : 'cabañas libres'}`;
      html += `<button type="button" class="${cls.join(' ')}" data-date="${t}" ${disabled ? 'disabled' : ''} aria-label="${fmtLong(date)}${status}">${d}</button>`;
    }
    return html + '</div></div>';
  };

  const renderCal = () => {
    const second = new Date(viewMonth.getFullYear(), viewMonth.getMonth() + 1, 1);
    calEl.innerHTML = renderMonth(viewMonth) + renderMonth(second);
    $('[data-cal-prev]').disabled = viewMonth <= firstMonth;
    nextBtn.disabled = !(checkIn && checkOut);
    updateSummary();
  };

  const updateSummary = () => {
    const list = $('[data-summary-list]');
    const p = $('[data-summary]');
    if (!checkIn) { p.textContent = 'Elegí tus fechas en el calendario.'; p.hidden = false; list.hidden = true; return; }
    p.hidden = !!checkOut;
    if (!checkOut) p.textContent = 'Ahora elegí el día de salida.';
    list.hidden = false;
    $('[data-in]').textContent = fmt(checkIn);
    $('[data-out]').textContent = checkOut ? fmt(checkOut) : '—';
    $('[data-nights]').textContent = checkOut ? nights() : '—';

    // Cabañas libres en todo el rango: se informan y se marcan en el selector.
    const freeRow = $('[data-free-row]');
    const free = checkOut ? freeBetween(checkIn, checkOut) : [];
    freeRow.hidden = !(busy && checkOut);
    $('[data-free]').textContent = free.map(c => c.id).join(', ') || 'ninguna';
    [...cabinSelect.options].forEach(o => {
      if (!o.value) return;
      const c = cabins.find(c => String(c.id) === o.value);
      const taken = busy && checkOut && !free.includes(c);
      o.disabled = !!taken;
      o.textContent = `${c.name} · ${c.capacity}${taken ? ' (ocupada esas fechas)' : ''}`;
      if (taken && cabinSelect.value === o.value) cabinSelect.value = '';
    });
  };

  calEl.addEventListener('click', e => {
    const b = e.target.closest('[data-date]');
    if (!b) return;
    const d = new Date(Number(b.dataset.date));
    if (!checkIn || checkOut || d <= checkIn) { checkIn = d; checkOut = null; }
    else checkOut = d;
    renderCal();
  });
  $('[data-cal-prev]').addEventListener('click', () => { viewMonth.setMonth(viewMonth.getMonth() - 1); renderCal(); });
  $('[data-cal-next]').addEventListener('click', () => { viewMonth.setMonth(viewMonth.getMonth() + 1); renderCal(); });
  renderCal();
  loadAvailability();

  const steps = $$('[data-step]');
  const labels = $$('[data-step-label]');
  const goTo = n => {
    steps.forEach(s => { s.hidden = s.dataset.step !== String(n); });
    labels.forEach(l => {
      const k = Number(l.dataset.stepLabel);
      l.classList.toggle('is-active', k === n);
      l.classList.toggle('is-done', k < n);
    });
  };
  $$('[data-go]').forEach(b => b.addEventListener('click', () => goTo(Number(b.dataset.go))));

  const form = $('[data-step="2"]');
  form.addEventListener('submit', e => {
    e.preventDefault();
    const data = new FormData(form);
    const ok = data.get('nombre').trim() && data.get('personas');
    $('[data-error]').hidden = !!ok;
    if (!ok) return;

    const cabin = cabins.find(c => String(c.id) === data.get('cabana'));
    const lines = [
      `¡Hola! Soy ${data.get('nombre').trim()} y quería consultar disponibilidad:`,
      `• Llegada: ${fmtLong(checkIn)}`,
      `• Salida: ${fmtLong(checkOut)} (${nights()} ${nights() === 1 ? 'noche' : 'noches'})`,
      `• Personas: ${data.get('personas')}`,
      `• Cabaña: ${cabin ? cabin.name : 'la que me recomienden'}`
    ];
    if (data.get('desayuno')) lines.push('• Me interesa el desayuno');
    const notes = data.get('comentarios').trim();
    if (notes) lines.push('', notes);
    const msg = lines.join('\n');

    $('[data-message]').textContent = msg;
    $('[data-send]').href = `https://wa.me/${whatsapp}?text=${encodeURIComponent(msg)}`;
    goTo(3);
  });

  /* ---------- Aparición al hacer scroll ---------- */
  $$('.section-head, .story .narrow, .amenities li, .mosaic figure, .plan, .contact-grid > *').forEach(el => el.classList.add('reveal'));
  const io = new IntersectionObserver(entries => entries.forEach(en => {
    if (en.isIntersecting) { en.target.classList.add('is-in'); io.unobserve(en.target); }
  }), { rootMargin: '0px 0px -8% 0px' });
  $$('.reveal').forEach(el => io.observe(el));
})();
