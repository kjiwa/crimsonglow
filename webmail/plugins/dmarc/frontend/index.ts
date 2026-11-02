import { registry } from '../../../frontend/src/plugin-registry';
import './dmarc-page';

registry.registerRoute({
    path: '/dmarc',
    component: 'alps-dmarc-page',
    pluginId: 'dmarc'
});

registry.registerNavTab({
    id: 'dmarc',
    pluginId: 'dmarc',
    labelKey: 'navigation.dmarc',
    icon: 'verifiedBadge',
    order: 40
});
